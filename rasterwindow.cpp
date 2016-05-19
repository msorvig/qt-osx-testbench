/****************************************************************************
**
** Copyright (C) 2015 The Qt Company Ltd.
** Contact: http://www.qt.io/licensing/
**
** This file is part of the test suite of the Qt Toolkit.
**
** $QT_BEGIN_LICENSE:LGPL21$
** Commercial License Usage
** Licensees holding valid commercial Qt licenses may use this file in
** accordance with the commercial license agreement provided with the
** Software or, alternatively, in accordance with the terms contained in
** a written agreement between you and The Qt Company. For licensing terms
** and conditions see http://www.qt.io/terms-conditions. For further
** information use the contact form at http://www.qt.io/contact-us.
**
** GNU Lesser General Public License Usage
** Alternatively, this file may be used under the terms of the GNU Lesser
** General Public License version 2.1 or version 3 as published by the Free
** Software Foundation and appearing in the file LICENSE.LGPLv21 and
** LICENSE.LGPLv3 included in the packaging of this file. Please review the
** following information to ensure the GNU Lesser General Public License
** requirements will be met: https://www.gnu.org/licenses/lgpl.html and
** http://www.gnu.org/licenses/old-licenses/lgpl-2.1.html.
**
** As a special exception, The Qt Company gives you certain additional
** rights. These rights are described in The Qt Company LGPL Exception
** version 1.1, included in the file LGPL_EXCEPTION.txt in this package.
**
** $QT_END_LICENSE$
**
****************************************************************************/

#include "rasterwindow.h"
#include "glcontent.h"

//#define HAVE_PARTIAL_UPDATE

#include <QBackingStore>
#include <QPainter>
#include <QtWidgets>

QColor colorTable[] =
{
    QColor("#309f8f"),
    QColor("#a2bff2"),
    QColor("#c0ef8f")
};

// RasterWindow is a simple QRasterWindow subclass with
// full and partial updates.
RasterWindow::RasterWindow(const QByteArray &property, QRasterWindow *parent)
    : QRasterWindow(parent)
    , m_backgroundColorIndex(0)
    , m_mousePressed(false)
    , m_rect(0, 0, 40, 40)
{
    setProperty(property.constData(), true);
    initialize();
}

void RasterWindow::initialize()
{
}

void RasterWindow::mousePressEvent(QMouseEvent *event)
{
    m_mousePressed = true;
}

void RasterWindow::mouseMoveEvent(QMouseEvent *event)
{
    if (!m_mousePressed)
        return;
    
    QRect oldRect = m_rect;
    m_rect.moveCenter(event->pos());

#ifdef HAVE_PARTIAL_UPDATE
    update(oldRect);
    update(m_rect);
#else
    update();
#endif
}

void RasterWindow::mouseReleaseEvent(QMouseEvent *event)
{
    m_mousePressed = false;
}

void RasterWindow::keyPressEvent(QKeyEvent *event)
{
    switch (event->key()) {
    case Qt::Key_Backspace:
        m_text.chop(1);
        break;
    case Qt::Key_Enter:
    case Qt::Key_Return:
        m_text.append('\n');
        break;
    default:
        m_text.append(event->text());
        break;
    }
    update();
}

void RasterWindow::resizeEvent(QResizeEvent *event)
{
    ++m_backgroundColorIndex;
}

void RasterWindow::paintEvent(QPaintEvent *event)
{
//    qDebug() << "paintEvent" << event->rect();
    QPainter p(this);
    drawSimplePainterContent(&p, m_backgroundColorIndex, this->size());
    p.fillRect(m_rect, Qt::gray);
}
