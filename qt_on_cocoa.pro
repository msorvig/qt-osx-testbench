TEMPLATE = app

QT += gui widgets quick gui_private

CONFIG += c++11

HEADERS += \
    glcontent.h \
    openglwindow.h \
    openglwindowresize.h \
    rasterwindow.h \
    widgetwindow.h \

SOURCES += \
    glcontent.cpp \
    openglwindow.cpp \
    openglwindowresize.cpp \
    rasterwindow.cpp \
    widgetwindow.cpp \

OBJECTIVE_SOURCES += \
    main.mm \
    nativecocoaview.mm \

LIBS += -framework AppKit -framework QuartzCore
