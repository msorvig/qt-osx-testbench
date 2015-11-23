#include <QtGui/QtGui>

void drawSimpleGLContent(int frame)
{
    glClearColor(0, 0, 0.5, 0.5);
    glClear(GL_COLOR_BUFFER_BIT);

    glColor3f(0.7, 0.4, 0.4);
    glLoadIdentity();
    glRotatef(frame, 0, 0, 1);

    glBegin(GL_TRIANGLES);
        glVertex3f(0, 0.6, 0);
        glVertex3f(-0.3, -0.3, 0);
        glVertex3f(0.3, -0.3, 0);
    glEnd();
}

static QColor colorTable[] =
{
    QColor("#309f8f"),
    QColor("#a2bff2"),
    QColor("#c0ef8f")
};

QImage drawSimpleImageContent(int frame, QSize size)
{
    QImage image(size, QImage::Format_ARGB32_Premultiplied);
    QPainter p(&image);
    QColor backgroundColor = colorTable[frame % (sizeof(colorTable) / sizeof(colorTable[0]))].rgba();
    p.fillRect(QRect(QPoint(), size), backgroundColor);
    return image;
}
