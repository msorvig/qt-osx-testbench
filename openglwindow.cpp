
#include "openglwindow.h"
#include "glcontent.h"

OpenGLWindow::OpenGLWindow()
    : QOpenGLWindow(QOpenGLWindow::NoPartialUpdate)
{

}

void OpenGLWindow::paintGL()
{
//    qDebug() << "paintGL" << this;
    ++frame;
    drawSimpleGLContent(frame);
    update();
}

void OpenGLWindow::resizeGL(int w, int h)
{

}

#include "moc_openglwindow.cpp"

