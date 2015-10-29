#include "widgetwindow.h"
#include <QtWidgets>

RedWidget::RedWidget()
{
    qDebug() << "RedWidget construct";

    QHBoxLayout *hlayout = new QHBoxLayout();

    QPushButton *push = new QPushButton("Push");
    QCheckBox *disable = new QCheckBox("Disable");
    QLineEdit *edit = new QLineEdit();
    QObject::connect(disable, &QCheckBox::stateChanged, [=](int state){
        edit->setDisabled(state);
        push->setDisabled(state);
    });

    hlayout->addWidget(push);
    hlayout->addWidget(disable);
    hlayout->addWidget(edit);

    QVBoxLayout *vlayout = new QVBoxLayout();
    vlayout->addLayout(hlayout);
    setLayout(vlayout);

    //setMask(QRegion(QRect(0,0, 200, 75)));
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
    Q_UNUSED(event);
//    qDebug() << "RedWidget::paintEvent" << event->rect();

    QPainter p(this);
    QRect rect(QPoint(0, 0), size());
    p.fillRect(rect, QColor(133, 50, 50));
}
