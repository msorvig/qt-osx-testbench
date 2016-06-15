What IS this thing anyway
==========================================

The OS Testbench is testing :

* update and animation performance (steady 60 fps)
* proper resize behavior (don't flicker).

To accomplish this the test allows running _test cases_ in
_test configurations_ with _test options_. 

The test cases are different content types: 

* NSOpenGLView
* NSOpenGLLayer
* NSView (raster)
* QOpenGLWindow
* QRasterWindow
* QWidget(Window)
* QQuickWindow
* ++
    
The test configurations are ways of hosting the test cases:

* As a child of a NSView
* As the content view for a NSWindow
* As a top-level QWindow
* As a child of a QWindow

Options include

* Content layer/no layer
* Hosting view layer/no layer
* Animations (Timer/CVDIsplayLink driven)
