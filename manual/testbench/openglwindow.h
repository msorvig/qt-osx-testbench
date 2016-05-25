#ifndef OPENGLWINDOW_H
#define OPENGLWINDOW_H

#include <QOpenGLWindow>

class OpenGLWindow : public QOpenGLWindow
{
    Q_OBJECT

public:
    OpenGLWindow();

protected:
    void paintGL() Q_DECL_OVERRIDE;
    void resizeGL(int w, int h) Q_DECL_OVERRIDE;
private:
    int frame;
};

#endif
