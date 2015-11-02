TEMPLATE = app

QT += gui widgets quick gui_private

CONFIG += c++11

OBJECTIVE_SOURCES += \
    main.mm \
    nativecocoaview.mm

HEADERS += rasterwindow.h
SOURCES += rasterwindow.cpp
HEADERS += openglwindow.h
SOURCES += openglwindow.cpp
HEADERS += openglwindowresize.h
SOURCES += openglwindowresize.cpp
HEADERS += widgetwindow.h
SOURCES += widgetwindow.cpp

LIBS += -framework AppKit -framework QuartzCore
