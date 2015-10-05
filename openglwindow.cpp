
#include "openglwindow.h"

#include <QFileInfo>

static QPainterPath painterPathForTriangle()
{
    static const QPointF bottomLeft(-1.0, -1.0);
    static const QPointF top(0.0, 1.0);
    static const QPointF bottomRight(1.0, -1.0);

    QPainterPath path(bottomLeft);
    path.lineTo(top);
    path.lineTo(bottomRight);
    path.closeSubpath();
    return path;
}

static const char vertex_shader[] =
    "attribute highp vec3 vertexCoord;"
    "void main() {"
    "   gl_Position = vec4(vertexCoord,1.0);"
    "}";

static const char fragment_shader[] =
    "void main() {"
    "   gl_FragColor = vec4(0.0,1.0,0.0,1.0);"
    "}";

static const float vertices[] = { -1, -1, 0,
                                  -1,  1, 0,
                                  1, -1, 0,
                                  1,  1, 0 };

FragmentToy::FragmentToy(const QString &fragmentSource, QObject *parent)
    : QObject(parent)
    , m_recompile_shaders(true)
{
    if (QFile::exists(fragmentSource)) {
        QFileInfo info(fragmentSource);
        m_fragment_file_last_modified = info.lastModified();
        m_fragment_file = fragmentSource;
#ifndef QT_NO_FILESYSTEMWATCHER
        m_watcher.addPath(info.canonicalPath());
        QObject::connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, &FragmentToy::fileChanged);
#endif
    }
}

void FragmentToy::draw(const QSize &windowSize)
{
    if (!m_program)
        initializeOpenGLFunctions();

    glDisable(GL_STENCIL_TEST);
    glDisable(GL_DEPTH_TEST);

    glClearColor(0.3, 0, 0.3, 1);
    glClear(GL_COLOR_BUFFER_BIT);
    if (!m_vao.isCreated())
        m_vao.create();

    QOpenGLVertexArrayObject::Binder binder(&m_vao);

    if (!m_vertex_buffer.isCreated()) {
        m_vertex_buffer.create();
        m_vertex_buffer.bind();
        m_vertex_buffer.allocate(vertices, sizeof(vertices));
        m_vertex_buffer.release();
    }

    if (!m_program) {
        m_program.reset(new QOpenGLShaderProgram);
        m_program->create();
        m_vertex_shader.reset(new QOpenGLShader(QOpenGLShader::Vertex));
        if (!m_vertex_shader->compileSourceCode(vertex_shader)) {
            qWarning() << "Failed to compile the vertex shader:" << m_vertex_shader->log();
        }
        if (!m_program->addShader(m_vertex_shader.data())) {
            qWarning() << "Failed to add vertex shader to program:" << m_program->log();
        }
    }

    if (!m_fragment_shader && m_recompile_shaders) {
        QByteArray data;
        if (m_fragment_file.size()) {
            QFile file(m_fragment_file);
            if (file.open(QIODevice::ReadOnly)) {
                data = file.readAll();
            } else {
                qWarning() << "Failed to load input file, falling back to default";
                data = QByteArray::fromRawData(fragment_shader, sizeof(fragment_shader));
            }
        } else {
            QFile qrcFile(":/background.frag");
            if (qrcFile.open(QIODevice::ReadOnly))
                data = qrcFile.readAll();
            else
                data = QByteArray::fromRawData(fragment_shader, sizeof(fragment_shader));
        }
        if (data.size()) {
            m_fragment_shader.reset(new QOpenGLShader(QOpenGLShader::Fragment));
            if (!m_fragment_shader->compileSourceCode(data)) {
                qWarning() << "Failed to compile fragment shader:" << m_fragment_shader->log();
                m_fragment_shader.reset(Q_NULLPTR);
            }
        } else {
            qWarning() << "Unknown error, no fragment shader";
        }

        if (m_fragment_shader) {
            if (!m_program->addShader(m_fragment_shader.data())) {
                qWarning() << "Failed to add fragment shader to program:" << m_program->log();
            }
        }
    }

    if (m_recompile_shaders) {
        m_recompile_shaders = false;

        if (m_program->link()) {
            m_vertex_coord_pos = m_program->attributeLocation("vertexCoord");
        } else {
            qWarning() << "Failed to link shader program" << m_program->log();
        }

    }

    if (!m_program->isLinked())
        return;

    m_program->bind();

    m_vertex_buffer.bind();
    m_program->setAttributeBuffer("vertexCoord", GL_FLOAT, 0, 3, 0);
    m_program->enableAttributeArray("vertexCoord");
    m_vertex_buffer.release();

    m_program->setUniformValue("currentTime", (uint) QDateTime::currentDateTime().toMSecsSinceEpoch());
    m_program->setUniformValue("windowSize", windowSize);

    QOpenGLContext::currentContext()->functions()->glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

    m_program->release();
}

void FragmentToy::fileChanged(const QString &path)
{
    Q_UNUSED(path);
    if (QFile::exists(m_fragment_file)) {
        QFileInfo fragment_source(m_fragment_file);
        if (fragment_source.lastModified() > m_fragment_file_last_modified) {
            m_fragment_file_last_modified = fragment_source.lastModified();
            m_recompile_shaders = true;
            if (m_program) {
                m_program->removeShader(m_fragment_shader.data());
                m_fragment_shader.reset(Q_NULLPTR);
            }
        }
    } else {
        m_recompile_shaders = true;
        if (m_program) {
            m_program->removeShader(m_fragment_shader.data());
            m_fragment_shader.reset(Q_NULLPTR);
        }
    }
}


// Use NoPartialUpdate. This means that all the rendering goes directly to
// the window surface, no additional framebuffer object stands in the
// middle. This is fine since we will clear the entire framebuffer on each
// paint. Under the hood this means that the behavior is equivalent to the
// manual makeCurrent - perform OpenGL calls - swapBuffers loop that is
// typical in pure QWindow-based applications.

OpenGLWindow::OpenGLWindow()
    : QOpenGLWindow(QOpenGLWindow::NoPartialUpdate)
    , m_fragment_toy("./background.frag")
    , m_text_layout("The triangle and this text is rendered with QPainter")
    , m_animate(false)
{
    m_view.lookAt(QVector3D(3,1,1),
                  QVector3D(0,0,0),
                  QVector3D(0,1,0));

    QLinearGradient gradient(QPointF(-1,-1), QPointF(1,1));
    gradient.setColorAt(0, Qt::red);
    gradient.setColorAt(1, Qt::green);

    m_brush = QBrush(gradient);

    setAnimating(m_animate);
}

void OpenGLWindow::paintGL()
{
    m_fragment_toy.draw(size());

    QPainter p(this);
    p.setWorldTransform(m_window_normalised_matrix.toTransform());

    QMatrix4x4 mvp = m_projection * m_view * m_model_triangle;
    p.setTransform(mvp.toTransform(), true);

    p.fillPath(painterPathForTriangle(), m_brush);

    QTransform text_transform = (m_window_painter_matrix * m_view * m_model_text).toTransform();
    p.setTransform(text_transform, false);
    p.setPen(QPen(Qt::white));
    m_text_layout.prepare(text_transform);
    qreal x = - (m_text_layout.size().width() / 2);
    qreal y = 0;
    p.drawStaticText(x, y, m_text_layout);

    m_model_triangle.rotate(-1, 0, 1, 0);
    m_model_text.rotate(1, 0, 1, 0);
}

void OpenGLWindow::resizeGL(int w, int h)
{
    m_window_normalised_matrix.setToIdentity();
    m_window_normalised_matrix.translate(w / 2.0, h / 2.0);
    m_window_normalised_matrix.scale(w / 2.0, -h / 2.0);

    m_window_painter_matrix.setToIdentity();
    m_window_painter_matrix.translate(w / 2.0, h / 2.0);

    m_text_layout.setTextWidth(std::max(w * 0.2, 80.0));

    m_projection.setToIdentity();
    m_projection.perspective(45.f, qreal(w) / qreal(h), 0.1f, 100.f);
}

void OpenGLWindow::keyPressEvent(QKeyEvent *e)
{
    if (e->key() == Qt::Key_P) { // pause
        m_animate = !m_animate;
        setAnimating(m_animate);
    }
}

void OpenGLWindow::setAnimating(bool enabled)
{
    if (enabled) {
        // Animate continuously, throttled by the blocking swapBuffers() call the
        // QOpenGLWindow internally executes after each paint. Once that is done
        // (frameSwapped signal is emitted), we schedule a new update. This
        // obviously assumes that the swap interval (see
        // QSurfaceFormat::setSwapInterval()) is non-zero.
        connect(this, SIGNAL(frameSwapped()), this, SLOT(update()));
        update();
    } else {
        disconnect(this, SIGNAL(frameSwapped()), this, SLOT(update()));
    }
}

#include "moc_openglwindow.cpp"

