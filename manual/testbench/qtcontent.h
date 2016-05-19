#ifndef QTCONTENT_H
#define QTCONTENT_H

#include <QtWidgets>
#include <QtQuick>

class QtOpenGLWidget : public QOpenGLWidget
{
public:
    QtOpenGLWidget(const QByteArray &property = QByteArray());
    void initializeGL();
    void resizeGL(int w, int h);
    void paintGL();
private:
    int frame;
};

#endif
