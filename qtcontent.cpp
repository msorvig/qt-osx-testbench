#include <qtcontent.h>
#include "glcontent.h"

QtOpenGLWidget::QtOpenGLWidget(const QByteArray &property)
:QOpenGLWidget(0)
{
    setProperty(property.constData(), true);

}

void QtOpenGLWidget::initializeGL()
{
    
}

void QtOpenGLWidget::resizeGL(int w, int h)
{
    
}

void QtOpenGLWidget::paintGL()
{
    ++frame;
    drawSimpleGLContent(frame);
    update();
}
