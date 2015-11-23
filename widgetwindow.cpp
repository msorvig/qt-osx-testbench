#include "widgetwindow.h"
#include <QtWidgets>

RedWidget::RedWidget()
{
    qDebug() << "RedWidget construct";

    QHBoxLayout *hlayout1 = new QHBoxLayout();
    QHBoxLayout *hlayout2 = new QHBoxLayout();

    QPushButton *push = new QPushButton("Push");
    QCheckBox *disable = new QCheckBox("Disable");
    QLineEdit *edit = new QLineEdit();
    QSlider *slider = new QSlider();
    slider->setOrientation(Qt::Horizontal);

    QObject::connect(disable, &QCheckBox::stateChanged, [=](int state){
        edit->setDisabled(state);
        push->setDisabled(state);
    });

    hlayout1->addWidget(push);
    hlayout1->addWidget(disable);
    hlayout1->addWidget(edit);
    hlayout2->addWidget(slider);

    QVBoxLayout *vlayout = new QVBoxLayout();
    vlayout->addLayout(hlayout1);
    vlayout->addLayout(hlayout2);
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
