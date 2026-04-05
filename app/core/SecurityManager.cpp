#include "SecurityManager.h"
#include <QLoggingCategory>

Q_LOGGING_CATEGORY(exoSecurity, "exo.security")

SecurityManager *SecurityManager::s_instance = nullptr;

SecurityManager::SecurityManager(QObject *parent)
    : QObject(parent)
{
    // Default allowed hosts for EXO services
    m_allowedHosts = {
        "localhost",
        "127.0.0.1",
        "api.anthropic.com",
        "api.openweathermap.org",
    };
}

SecurityManager* SecurityManager::instance()
{
    if (!s_instance)
        s_instance = new SecurityManager();
    return s_instance;
}

// ── Permissions ──────────────────────────────────────

void SecurityManager::grant(const QString &module, const QString &permission)
{
    QMutexLocker lock(&m_mutex);
    m_permissions[module].insert(permission);
    qCDebug(exoSecurity) << "Granted" << permission << "to" << module;
}

void SecurityManager::revoke(const QString &module, const QString &permission)
{
    QMutexLocker lock(&m_mutex);
    auto it = m_permissions.find(module);
    if (it != m_permissions.end())
        it->remove(permission);
}

bool SecurityManager::isAllowed(const QString &module, const QString &permission) const
{
    QMutexLocker lock(&m_mutex);
    auto it = m_permissions.constFind(module);
    if (it == m_permissions.constEnd())
        return false;
    return it->contains(permission) || it->contains("*");
}

QStringList SecurityManager::permissionsFor(const QString &module) const
{
    QMutexLocker lock(&m_mutex);
    auto it = m_permissions.constFind(module);
    if (it == m_permissions.constEnd())
        return {};
    return it->values();
}

// ── API Key Masking ──────────────────────────────────

QString SecurityManager::maskApiKey(const QString &key)
{
    if (key.length() <= 8)
        return QStringLiteral("****");
    return key.left(4) + QStringLiteral("...") + key.right(4);
}

QString SecurityManager::maskSensitive(const QString &text)
{
    // Mask patterns: sk-ant-*, Bearer *, API keys
    QString result = text;
    static const QRegularExpression re(
        QStringLiteral("(sk-ant-[a-zA-Z0-9-]{8})[a-zA-Z0-9-]+"),
        QRegularExpression::NoPatternOption);
    result.replace(re, QStringLiteral("\\1****"));
    return result;
}

// ── Audit ────────────────────────────────────────────

void SecurityManager::audit(const QString &action, const QString &module,
                            const QString &principal, bool allowed,
                            const QJsonObject &details)
{
    QMutexLocker lock(&m_mutex);

    AuditEntry entry;
    entry.action    = action;
    entry.module    = module;
    entry.principal = principal;
    entry.allowed   = allowed;
    entry.timestamp = QDateTime::currentDateTime();
    entry.details   = details;

    if (m_auditLog.size() >= MAX_AUDIT_ENTRIES)
        m_auditLog.removeFirst();
    m_auditLog.append(entry);

    if (!allowed) {
        qCWarning(exoSecurity) << "DENIED:" << principal << action << "on" << module;
        lock.unlock();
        emit securityViolation(module, action);
    } else {
        qCDebug(exoSecurity) << principal << action << "on" << module;
        lock.unlock();
        emit auditLogged(entry.toJson());
    }
}

// ── Network Validation ───────────────────────────────

bool SecurityManager::isAllowedHost(const QString &host) const
{
    QMutexLocker lock(&m_mutex);
    return m_allowedHosts.contains(host);
}

void SecurityManager::addAllowedHost(const QString &host)
{
    QMutexLocker lock(&m_mutex);
    m_allowedHosts.insert(host);
}

// ── QML API ──────────────────────────────────────────

QJsonObject SecurityManager::getSecuritySummary() const
{
    QMutexLocker lock(&m_mutex);
    int denied = 0;
    for (const auto &entry : m_auditLog) {
        if (!entry.allowed) ++denied;
    }
    return {
        {"module_count", m_permissions.size()},
        {"audit_entries", m_auditLog.size()},
        {"denied_actions", denied},
        {"allowed_hosts", static_cast<int>(m_allowedHosts.size())},
    };
}

QJsonArray SecurityManager::getAuditLog(int maxCount) const
{
    QMutexLocker lock(&m_mutex);
    QJsonArray arr;
    int start = qMax(0, m_auditLog.size() - maxCount);
    for (int i = start; i < m_auditLog.size(); ++i)
        arr.append(m_auditLog[i].toJson());
    return arr;
}

bool SecurityManager::checkPermission(const QString &module,
                                      const QString &permission) const
{
    return isAllowed(module, permission);
}
