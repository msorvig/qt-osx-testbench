#include <qtcontent.h>
#include "glcontent.h"

extern bool g_animate;

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
    drawSimpleGLContent(frame);
    if (g_animate) {
        ++frame;
        update();
    }
}
