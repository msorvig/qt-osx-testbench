#include <QtCore>
#include <QtGui>
#include <QtWidgets>

bool g_useAlphaFormat = true;

class ColorRasterWindow : public QRasterWindow
{
public:
    QColor fillColor;

    ColorRasterWindow(QWindow *parent = 0)
    :QRasterWindow(parent)
    {
        fillColor = QColor(Qt::blue).darker();
        
        QSurfaceFormat format;
        format.setAlphaBufferSize(g_useAlphaFormat ? 8 : 0);
        setFormat(format);
    }
    
    void paintEvent(QPaintEvent *ev)
    {
        qDebug() << "paint" << this << ev->rect();
        fillColor = QColor(fillColor.green(), fillColor.blue(), fillColor.red(), 255);
        QPainter p(this);
        foreach (QRect rect, ev->region().rects()) {
            p.fillRect(rect, fillColor);
        }
    }
    
    void resizeEvent(QResizeEvent *ev)
    {
        qDebug() << "resize" << this;
    }

    void mousePressEvent(QMouseEvent *ev)
    {
        qDebug() << "press" << this;
        update();
    }
};

class ColorRasterWidget : public QWidget
{
public:
    QColor fillColor;
    
    ColorRasterWidget(QWidget *parent = 0)
    :QWidget(parent)
    {
        fillColor = QColor(Qt::blue).darker();
    
//        QSurfaceFormat format;
//        format.setAlphaBufferSize(g_useAlphaFormat ? 8 : 0);
//        setFormat(format);
    }
    
    void paintEvent(QPaintEvent *ev)
    {
        qDebug() << "paint" << this->windowHandle() << ev->rect();
        fillColor = QColor(fillColor.green(), fillColor.blue(), fillColor.red(), 255);
        QPainter p(this);
        foreach (QRect rect, ev->region().rects()) {
            p.fillRect(rect, fillColor);
        }
    }
    
    void resizeEvent(QResizeEvent *ev)
    {
        qDebug() << "resize" << this->windowHandle();
    }

    void mousePressEvent(QMouseEvent *ev)
    {
        qDebug() << "press" << this->windowHandle();
        update();
    }
};

int main(int argc, char **argv)
{
    QApplication app(argc, argv);
    
    // Widget
    {
        ColorRasterWidget *parent = new ColorRasterWidget();
        parent->setWindowTitle("Widget");
        parent->setGeometry(50, 50, 200, 200);
        parent->show();

        ColorRasterWidget *child = new ColorRasterWidget(parent);
        child->winId(); // force native;
        child->fillColor = QColor(Qt::red).darker().darker();
        child->setGeometry(20, 20, 50, 50);
        child->show();
    }

    // Window
    {
        ColorRasterWindow *parent = new ColorRasterWindow();
        parent->setTitle("Window");
        parent->setGeometry(300, 50, 200, 200);
        parent->show();

        ColorRasterWindow *child = new ColorRasterWindow(parent);
        child->fillColor = QColor(Qt::red).darker().darker();
        child->setGeometry(20, 20, 50, 50);
        child->show();
    }        
    return app.exec();
}
