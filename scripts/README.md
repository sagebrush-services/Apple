# iOS Screenshot Automation

Run:

```bash
./scripts/capture_ios_screenshots.sh
```

This does the following:

- runs the screenshot generation test
- writes iPhone PNG files to `artifacts/ios-screenshots/iphone` (or `$SAGEBRUSH_SCREENSHOT_OUTPUT_DIR/iphone`)
- writes iPad PNG files to `artifacts/ios-screenshots/ipad` (or `$SAGEBRUSH_SCREENSHOT_OUTPUT_DIR/ipad`)
- writes side-by-side `review.html` to `$SAGEBRUSH_SCREENSHOT_OUTPUT_DIR`
- opens `review.html`

No Android automation is included in this repository.
