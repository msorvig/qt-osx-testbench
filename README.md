Qt on OS X Test Bench
============================

The purpose of this repo is develop new tests for the Qt OS X ("cocoa") platform plugin. The main
tests are:

* QWindow on OS X manual test: manual/testbench
* QCocoaWindow auto test: auto/qcocoawindow

Manual Test: qt-osx-testbench
-----------------------------

The manual test tests QWindow in various _external_ configurations

* A stand-alone top-level QWindow
* A QWindow embedded in a NSView hierarchy as a child NSView
  * with an ancestor Core Animation Layer
  * without any layers present
* A QWindow embedded in a NSWindow hierarchy as a child NSWindow

Several _internal_ configurations are tested as well:

* Layer vs Non-layer
* Raster and OpenGL content
* Qt Widgets and Qt Quick Content.

Test focus include update and animation performance (steady 60 fps), and proper resize
behavior (don't flicker)-. As a means to this end this test bench implements several of the
configurations using native code only. This helps isolate native API usage errors and
demonstrate whats possible to implement on the plaform.

TODO:

* Implement a multi-threaded native OpenGL test case
  * Driven by CVDisplayLink
  * Blocking on SwapBuffers.

* Proper NSView stacking using sortSubviewsUsingFunction, instead of the current orderFront hack

* Make QQuickWindow animate and resize properly
* Make QGLWidget animate and resize properly

Auto Test: qt-osx-tst_qcocoawindow
---------------------------------

This test auto-tests aspects of the QCocoaWindow implementation, including:
* Native view instance counts (leaks)
* Event processing
* Expose and repaint behavior.

The test tests native views (for verifying assumptions) and QWindow/QCocoaWindow.
There is no Qt Widgets and Qt Quick usage.

