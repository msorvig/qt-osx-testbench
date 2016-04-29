#include <QtCore>
#include <QtGui>

class AnimatedRasterWindow : public QRasterWindow
{
public:
    int height;
    
    AnimatedRasterWindow()
    :QRasterWindow()
    {
        height = 200;
    }
    
    void paintEvent(QPaintEvent *ev) {

        QPainter p(this);
        foreach (QRect rect, ev->region().rects()) {
            p.fillRect(rect, QColor(Qt::blue));
        }
        
        QTimer::singleShot(10, [this](){
            height += 10;
            height %= 300;
            setGeometry(40, 40, 200, 200 + height);
        });
    }
};

class AnimatedOpenGLWindow : public QOpenGLWindow
{
public:
    int height;
    
    AnimatedOpenGLWindow()
    :QOpenGLWindow()
    {
        height = 200;
    }
    
    void paintGL()
    {
        QColor fillColor(Qt::blue);
        glClearColor(fillColor.redF(), fillColor.greenF(), fillColor.blueF(), fillColor.alphaF());
        glClear(GL_COLOR_BUFFER_BIT);

        // not necessarily correct animation technique.
        QTimer::singleShot(5, [this](){
            height += 10;
            height %= 300;
            setGeometry(40, 40, 200, 50 + height);
        });
    }
};

int main(int argc, char **argv)
{
    QGuiApplication app(argc, argv);

//    AnimatedRasterWindow animatedWindow;
 //   animatedWindow.show();
    
    AnimatedOpenGLWindow animatedOpenGLWindow;
    animatedOpenGLWindow.show();

    return app.exec();
}
