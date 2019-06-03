TEMPLATE = app

QT += core gui gui-private testlib

OBJECTS_DIR = .obj
MOC_DIR = .moc

# cocoaspy
### fixme
INCLUDEPATH += $$PWD/../../manual/testbench
HEADERS += $$PWD/../../manual/testbench/cocoaspy.h
OBJECTIVE_SOURCES += $$PWD/../../manual/testbench/cocoaspy.mm

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

# autotest support code
HEADERS += $$PWD/testsupport.h
OBJECTIVE_SOURCES += $$PWD/testsupport.mm

# QCocoaWindow unit test
OBJECTIVE_SOURCES += $$PWD/tst_qcocoawindow.mm
LIBS += -framework AppKit

# API usage switches. Comment in for Qt branches that
# have the new API / feature
#DEFINES += HAVE_TRANSFER_NATIVE_VIEW
#DEFINES += HAVE_QPAINTDEVICEWINDOW_REPAINT
#DEFINES += HAVE_LAZY_NATIVE_WINDOWS
#DEFINES += HAVE_CVDISPLAYLINK

# MacOS 10.14 disables CGEventPost for security reasons
# Things to try:
# Info.plist: NSAppleEventsUsageDescription
# .pro:       LIBS += -Wl,-sdk_version -Wl,10.13
#DEFINES += HAVE_WORKING_CGEVENTPOST
