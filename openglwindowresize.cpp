#include "openglwindowresize.h"

MyOpenGLWindow::MyOpenGLWindow(UpdateBehavior updateBehavior, QWindow *parent) :
        QOpenGLWindow(updateBehavior, parent)
    {
        m_window = 0;
        m_hasMouse = false;
    }

    void MyOpenGLWindow::paintGL()
    {
        glClearColor(1.0, 0.0, 0.0, 1.0);
        glClear(GL_COLOR_BUFFER_BIT);
    }

    void MyOpenGLWindow::setMainWindow(QWindow *mw)
    {
        m_window = mw;
    }


    void MyOpenGLWindow::mousePressEvent(QMouseEvent *e)
    {
        m_hasMouse = true;
        m_pressOrigin = e->pos();
        m_pressSize = size();
    }

    void MyOpenGLWindow::mouseReleaseEvent(QMouseEvent *e)
    {
        m_hasMouse = false;
    }

    void MyOpenGLWindow::mouseMoveEvent(QMouseEvent *e)
    {
        if(m_hasMouse)
        {
            int deltaX = e->pos().x() - m_pressOrigin.x();
            int deltaY = e->pos().y() - m_pressOrigin.y();

            QSize sz;

            sz.setWidth(m_pressSize.width() + deltaX);
            sz.setHeight(m_pressSize.height() + deltaY);

            //m_window->resize(sz);
            this->resize(sz);
        }
    }

