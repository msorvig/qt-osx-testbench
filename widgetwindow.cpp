#include "widgetwindow.h"
#include <QtWidgets>

RedWidget::RedWidget()
{
    qDebug() << "RedWidget construct";

    QHBoxLayout *hlayout = new QHBoxLayout();
    hlayout->addWidget(new QPushButton("Push"));
    hlayout->addWidget(new QLineEdit());

    QVBoxLayout *vlayout = new QVBoxLayout();
    vlayout->addLayout(hlayout);
    setLayout(vlayout);
    setAttribute(Qt::WA_LayoutUsesWidgetRect);
}

void RedWidget::showEvent(QShowEvent *)
{
    qDebug() << "RedWidget::show";
}

void RedWidget::hideEvent(QHideEvent *)
{
    qDebug() << "RedWidget::hide";
}

void RedWidget::resizeEvent(QResizeEvent *)
{
    qDebug() << "RedWidget::resize" << size();
}

void RedWidget::paintEvent(QPaintEvent *event)
{
    QPainter p(this);
    Q_UNUSED(event);
    QRect rect(QPoint(0, 0), size());
    qDebug() << "RedWidget::paintEvent" << event->rect();
    p.fillRect(rect, QColor(133, 50, 50));
}
