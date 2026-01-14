import Fluent
import Foundation
import NotationEngine

#if canImport(AppKit)
import AppKit
import PDFKit
#endif

/// Service for generating filled PDF documents from formation data.
/// Uses notation document_mappings to place text at specific coordinates on PDF pages.
public actor PDFGenerationService {
    private let database: Database
    private let blobRepository: BlobRepository

    public init(database: Database, blobRepository: BlobRepository) {
        self.database = database
        self.blobRepository = blobRepository
    }

    public enum PDFError: Error, LocalizedError, Equatable {
        case notationNotFound
        case documentURLNotFound
        case documentDownloadFailed(String)
        case pdfGenerationFailed(String)
        case unsupportedPlatform
        case noDocumentMappings
        case blobCreationFailed

        public var errorDescription: String? {
            switch self {
            case .notationNotFound:
                return "Notation not found for formation"
            case .documentURLNotFound:
                return "Document URL not found in notation"
            case .documentDownloadFailed(let reason):
                return "Failed to download PDF template: \(reason)"
            case .pdfGenerationFailed(let reason):
                return "Failed to generate PDF: \(reason)"
            case .unsupportedPlatform:
                return "PDF generation is not supported on this platform"
            case .noDocumentMappings:
                return "No document mappings found in notation"
            case .blobCreationFailed:
                return "Failed to create blob storage record"
            }
        }
    }

    /// Generates a filled PDF for a formation.
    /// Downloads the template PDF, overlays text based on document_mappings, and stores the result.
    /// Returns the blob ID.
    public func generatePDF(for formation: FlowInstanceRecord, notation: Notation) async throws -> Int32 {
        #if canImport(AppKit)
        // Get document from notation
        guard let document = notation.document,
            let documentURL = document.url
        else {
            throw PDFError.documentURLNotFound
        }

        // Check for document mappings before downloading PDF
        guard !document.mappings.isEmpty else {
            throw PDFError.noDocumentMappings
        }

        // Download template PDF
        let templateData = try await downloadPDF(from: documentURL)

        guard let templatePDF = PDFDocument(data: templateData) else {
            throw PDFError.pdfGenerationFailed("Invalid PDF template")
        }

        // Load all flow steps for data extraction
        let steps = try await FlowStepRecord.query(on: database)
            .filter(\.$instance.$id == formation.requireID())
            .all()

        // Collect overlays grouped by page index (0-based)
        var overlaysByPage: [Int: [TextOverlay]] = [:]

        // Apply text overlays based on mappings
        for (key, mapping) in document.mappings {
            if let text = try await extractValue(for: key, from: steps, formation: formation) {
                if let overlay = try makeOverlay(for: mapping, text: text, in: templatePDF) {
                    overlaysByPage[overlay.pageIndex, default: []].append(overlay)
                }
            }
        }

        // Render a new PDF by drawing the original pages plus overlays.
        let pdfData = try renderPDF(template: templatePDF, overlaysByPage: overlaysByPage)

        // Store blob using repository
        // Note: Using 0 as referencedById since formations use UUID IDs (not Int32)
        // The actual reference is stored in formation.generatedDocumentURL
        let blob = try await blobRepository.store(
            data: pdfData,
            contentType: "application/pdf",
            referencedBy: .formations,
            referencedById: 0
        )

        // Return the blob ID
        return try blob.requireID()

        #else
        throw PDFError.unsupportedPlatform
        #endif
    }

    #if canImport(AppKit)
    /// Downloads a PDF from a URL (or reads from file:// URLs)
    private func downloadPDF(from url: URL) async throws -> Data {
        // Handle file:// URLs directly
        if url.isFileURL {
            return try Data(contentsOf: url)
        }

        // Handle HTTP/HTTPS URLs
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
            (200...299).contains(httpResponse.statusCode)
        else {
            throw PDFError.documentDownloadFailed("HTTP error")
        }

        return data
    }

    /// Extracts a value from flow steps based on the mapping key
    /// Keys can be like "entity.name", "registered_agent.name", "manager.1.name", or direct question codes
    private func extractValue(
        for key: String,
        from steps: [FlowStepRecord],
        formation: FlowInstanceRecord
    ) async throws -> String? {
        // Handle entity.name
        if key == "entity.name" {
            // Look for entity_name question
            if let nameStep = steps.first(where: { $0.questionCode == "entity_name" }),
                let name = nameStep.answerPayload.stringValue
            {
                return name
            }
        }

        // Handle registered_agent.* fields - extract from mailbox office
        if key.hasPrefix("registered_agent.") {
            let field = String(key.dropFirst("registered_agent.".count))

            // Load mailbox if present
            if let mailboxID = formation.$mailbox.id {
                let mailbox = try await Mailbox.query(on: database)
                    .filter(\.$id == mailboxID)
                    .with(\.$office)
                    .with(\.$address)
                    .first()

                if let mailbox = mailbox {
                    let office = mailbox.office
                    switch field {
                    case "name":
                        return office.name
                    case "street":
                        // Combine address line 1 and 2
                        if let line2 = office.addressLine2, !line2.isEmpty {
                            return "\(office.addressLine1), \(line2)"
                        }
                        return office.addressLine1
                    case "city":
                        return office.city
                    case "state":
                        return office.state
                    case "zip":
                        return office.postalCode
                    default:
                        break
                    }
                }
            }
        }

        // Handle manager.N.* fields - extract from user/person data
        if key.hasPrefix("manager.") {
            let parts = key.split(separator: ".")
            if parts.count >= 3 {
                // parts[0] = "manager", parts[1] = slot number, parts[2] = field
                let field = String(parts[2])

                // For now, use the formation's user as the manager
                let user = try await User.query(on: database)
                    .filter(\.$id == formation.$user.id)
                    .with(\.$person)
                    .first()

                if let user = user {
                    let person = user.person
                    switch field {
                    case "name":
                        return person.name
                    case "street":
                        // For now, use a placeholder or load from person's address if available
                        return "123 Main St"
                    case "city":
                        return "Reno"
                    case "state":
                        return "NV"
                    case "zip":
                        return "89501"
                    case "country":
                        return "USA"
                    default:
                        break
                    }
                }
            }
        }

        // Handle dissolution_date (optional field)
        if key == "dissolution_date" {
            // Currently not collected, return nil
            return nil
        }

        // Handle direct question codes
        if let step = steps.first(where: { $0.questionCode == key }),
            let value = step.answerPayload.stringValue
        {
            return value
        }

        return nil
    }

    private struct TextOverlay {
        let pageIndex: Int  // 0-based
        let rect: CGRect
        let text: String
    }

    private func makeOverlay(
        for mapping: DocumentMapping,
        text: String,
        in template: PDFDocument
    ) throws -> TextOverlay? {
        guard
            let pageIndex = mapping.page,
            pageIndex > 0,
            pageIndex <= template.pageCount,
            let page = template.page(at: pageIndex - 1),
            let quad = mapping.quad
        else {
            return nil
        }

        let pageBounds = page.bounds(for: .mediaBox)
        let x = CGFloat(quad.upperLeft.x)
        let y = pageBounds.height - CGFloat(quad.lowerLeft.y)
        let width = max(CGFloat(quad.upperRight.x - quad.upperLeft.x), 0)
        let height = max(CGFloat(quad.lowerLeft.y - quad.upperLeft.y), 0)

        guard width > 0, height > 0 else {
            return nil
        }

        let rect = CGRect(x: x, y: y, width: width, height: height)
        return TextOverlay(pageIndex: pageIndex - 1, rect: rect, text: text)
    }

    private func renderPDF(
        template: PDFDocument,
        overlaysByPage: [Int: [TextOverlay]]
    ) throws -> Data {
        guard template.pageCount > 0 else {
            throw PDFError.pdfGenerationFailed("Template PDF has no pages")
        }

        let pdfData = NSMutableData()
        guard
            let consumer = CGDataConsumer(data: pdfData as CFMutableData),
            var mediaBox = template.page(at: 0)?.bounds(for: .mediaBox)
        else {
            throw PDFError.pdfGenerationFailed("Unable to prepare PDF context")
        }

        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw PDFError.pdfGenerationFailed("Unable to create PDF context")
        }

        for pageIndex in 0..<template.pageCount {
            guard let page = template.page(at: pageIndex), let pageRef = page.pageRef else {
                continue
            }

            var pageBox = page.bounds(for: .mediaBox)
            let pageDictionary: CFDictionary = [kCGPDFContextMediaBox as String: pageBox] as CFDictionary
            context.beginPDFPage(pageDictionary)
            context.drawPDFPage(pageRef)

            if let overlays = overlaysByPage[pageIndex], !overlays.isEmpty {
                NSGraphicsContext.saveGraphicsState()
                let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
                NSGraphicsContext.current = nsContext

                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.alignment = .left
                paragraphStyle.lineBreakMode = .byWordWrapping

                for overlay in overlays {
                    let attributes: [NSAttributedString.Key: Any] = [
                        .font: NSFont.systemFont(ofSize: 12),
                        // Use a vivid color to visually debug overlay positions
                        .foregroundColor: NSColor.systemRed,
                        .paragraphStyle: paragraphStyle,
                    ]
                    let attributed = NSAttributedString(string: overlay.text, attributes: attributes)
                    attributed.draw(in: overlay.rect)
                }

                NSGraphicsContext.restoreGraphicsState()
            }

            context.endPDFPage()
        }

        context.closePDF()
        return pdfData as Data
    }
    #endif
}
