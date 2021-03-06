TEMPLATE = app

QT += gui widgets quick gui_private quickwidgets platformsupport-private

CONFIG += c++11

HEADERS += \
    glcontent.h \
    openglwindow.h \
    openglwindowresize.h \
    rasterwindow.h \
    widgetwindow.h \
    cocoaspy.h \
    qtcontent.h

SOURCES += \
    glcontent.cpp \
    openglwindow.cpp \
    openglwindowresize.cpp \
    rasterwindow.cpp \
    widgetwindow.cpp \
    qtcontent.cpp

OBJECTIVE_SOURCES += \
    main.mm \
    nativecocoaview.mm \
    cocoaspy.mm \

LIBS += -framework AppKit -framework QuartzCore

DEFINES += HAVE_TRANSFER_NATIVE_VIEW
DEFINES += HAVE_QIMAGE_TONSIMAGE
