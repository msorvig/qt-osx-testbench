Qt on OS X Graphics Test Bench

The purpose of this repo is develop and test QWindow hosting
options on OS X. Configurations include:

* A stand-alone top-level QWindow
* A QWindow embedded in a NSView hierarchy as a child NSView
  * with an ancestor Core Animation Layer
  * without any layers present
* A QWindow embedded in a NSWindow hierarchy as a child NSWindow

Both raster and OpenGL QWindow content is tested. Test focus include
update and animation performance (steady 60 fps), and proper resize
behavior (don't flicker).

As a means to this end this test bench implements several of the 
configurations using native code only. This helps isolate native API
usage errors and demonstrate whats possible to implement on the plaform.

TODO:

* Implement a native OpenGL test case using NSView and NSOpenGLContext (not NSOpenGLView)
* Implement a native OpenGL test case using a CAOpenGLLayer
* Implement a multi-threaded native OpenGL test case
  * Driven by CVDisplayLink
  * Blocking on SwapBuffers.

* Proper NSView stacking using sortSubviewsUsingFunction, instead of the current orderFront hack

* Make QOpenGLWindow animate and resize properly
  * Make QQuickWindow animate and resize properly
  * Make QGLWidget animate and resize properly
 