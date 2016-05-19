#include <QtGui>

class MyOpenGLWindow : public QOpenGLWindow
{
public:
    MyOpenGLWindow(UpdateBehavior updateBehavior = NoPartialUpdate, QWindow *parent = 0);
    virtual void paintGL() override;
    void setMainWindow(QWindow *window);

private:
    bool m_hasMouse;
    QPoint m_pressOrigin;
    QSize m_pressSize;

    QWindow *m_window;

    virtual void mousePressEvent(QMouseEvent *e) override;
    virtual void mouseReleaseEvent(QMouseEvent *e) override;
    virtual void mouseMoveEvent(QMouseEvent *e) override;
};
