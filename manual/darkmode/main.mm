#include <QtGui>
#include <QtWidgets>
#include <AppKit/AppKit.h>


#if !QT_MACOS_PLATFORM_SDK_EQUAL_OR_ABOVE(__MAC_10_14)
@interface NSApplication (MojaveForwardDeclarations)
@property (strong) NSAppearance *appearance NS_AVAILABLE_MAC(10_14);
@end
#endif

class DarkModeController : public QWidget
{
public:
    DarkModeController() {
        QVBoxLayout *layout = new QVBoxLayout();
        setLayout(layout);
        
        layout->addWidget(new QLabel("Dark Mode Controller"));
        QCheckBox *lightAqua = new QCheckBox("Force light Aqua");
        connect(lightAqua, &QCheckBox::stateChanged, [](int state){
            if (state == 0) {
                NSApp.appearance = nil; // clear to inherit;
            } else {
                NSApp.appearance = [NSAppearance appearanceNamed:NSAppearanceNameAqua];
            }
        });
        layout->addWidget(lightAqua);
        layout->addWidget(new QLabel("Test Widgets Follow:"));
        QLineEdit *lineEdit = new QLineEdit("The best line edit in the world (tribute)");
        layout->addWidget(lineEdit);
        QPushButton *pushButton = new QPushButton("Pushit");
        layout->addWidget(pushButton);
        layout->addStretch();
    }
};

int main(int argc, char **argv)
{
    QApplication app(argc, argv);
    
    // Comment in next line to hardcode light aqua.
    // NSApp.appearance = [NSAppearance appearanceNamed:NSAppearanceNameAqua];
    
    DarkModeController controller;
    controller.resize(640, 480);
    controller.show();

    return app.exec();
}
