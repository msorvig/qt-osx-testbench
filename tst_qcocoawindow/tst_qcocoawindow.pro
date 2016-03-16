TEMPLATE = app

QT += core gui gui-private testlib platformsupport-private

OBJECTS_DIR = .obj
MOC_DIR = .moc

QMAKE_DOCS = $$PWD/tst_qcocoawindow.qdocconf

# cocoaspy
INCLUDEPATH += $$PWD/..
HEADERS += $$PWD/../cocoaspy.h
OBJECTIVE_SOURCES += $$PWD/../cocoaspy.mm

# native events
INCLUDEPATH += $$PWD/nativeevents
HEADERS += \
    $$PWD/nativeevents/nativeeventlist.h \
    $$PWD/nativeevents/qnativeevents.h
SOURCES += \
    $$PWD/nativeevents/nativeeventlist.cpp \
    $$PWD/nativeevents/qnativeevents.cpp \
    $$PWD/nativeevents/qnativeevents_mac.cpp
LIBS += -framework Carbon

# The Test
OBJECTIVE_SOURCES += $$PWD/tst_qcocoawindow.mm
LIBS += -framework AppKit

