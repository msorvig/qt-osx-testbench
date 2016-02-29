TEMPLATE = app

QT += core gui testlib

QMAKE_DOCS = $$PWD/tst_qcocoawindow.qdocconf

OBJECTIVE_SOURCES += $$PWD/tst_qcocoawindow.mm

INCLUDEPATH += $$PWD/..
HEADERS += $$PWD/../cocoaspy.h
OBJECTIVE_SOURCES += $$PWD/../cocoaspy.mm

LIBS += -framework AppKit
