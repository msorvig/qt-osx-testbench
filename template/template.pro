TEMPLATE = app

QT = core

CONFIG += c++11

OBJECTIVE_SOURCES += \
    template.mm \

LIBS += -framework AppKit -framework QuartzCore
