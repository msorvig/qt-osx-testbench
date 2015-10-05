#ifndef OPENGLWINDOW_H
#define OPENGLWINDOW_H

#include <QOpenGLWindow>
#include <QScreen>
#include <QPainter>
#include <QGuiApplication>
#include <QMatrix4x4>
#include <QStaticText>
#include <QKeyEvent>

#include <QObject>
#include <QFile>
#include <QDateTime>
#include <QFileSystemWatcher>
#include <QOpenGLVertexArrayObject>
#include <QOpenGLBuffer>
#include <QOpenGLShaderProgram>
#include <QOpenGLFunctions>
#include <math.h>

class FragmentToy : public QObject, protected QOpenGLFunctions
{
    Q_OBJECT
public:
    FragmentToy(const QString &fragmentSource, QObject *parent = 0);

    void draw(const QSize &windowSize);

private:
    void fileChanged(const QString &path);
    bool m_recompile_shaders;
#ifndef QT_NO_FILESYSTEMWATCHER
    QFileSystemWatcher m_watcher;
#endif
    QString m_fragment_file;
    QDateTime m_fragment_file_last_modified;

    QScopedPointer<QOpenGLShaderProgram> m_program;
    QScopedPointer<QOpenGLShader> m_vertex_shader;
    QScopedPointer<QOpenGLShader> m_fragment_shader;
    QOpenGLVertexArrayObject m_vao;
    QOpenGLBuffer m_vertex_buffer;
    GLuint m_vertex_coord_pos;
};

class OpenGLWindow : public QOpenGLWindow
{
    Q_OBJECT

public:
    OpenGLWindow();

protected:
    void paintGL() Q_DECL_OVERRIDE;
    void resizeGL(int w, int h) Q_DECL_OVERRIDE;
    void keyPressEvent(QKeyEvent *e) Q_DECL_OVERRIDE;

private:
    void setAnimating(bool enabled);

    QMatrix4x4 m_window_normalised_matrix;
    QMatrix4x4 m_window_painter_matrix;
    QMatrix4x4 m_projection;
    QMatrix4x4 m_view;
    QMatrix4x4 m_model_triangle;
    QMatrix4x4 m_model_text;
    QBrush m_brush;

    FragmentToy m_fragment_toy;
    QStaticText m_text_layout;
    bool m_animate;
};

#endif
