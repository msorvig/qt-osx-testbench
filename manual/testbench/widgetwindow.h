#include <QtWidgets>

class RedWidget : public QWidget
{
public:
    RedWidget();
    void showEvent(QShowEvent *);
    void hideEvent(QHideEvent *);
    void resizeEvent(QResizeEvent *);
    void paintEvent(QPaintEvent *event);
};
