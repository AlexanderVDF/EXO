#pragma once

#include <QObject>
#include <QSet>
#include <QVariantList>
#include <QTimer>
#include "ServiceRegistry.h"

// ═══════════════════════════════════════════════════════
//  SafeBootManager — EXO Safe Boot Orchestrator v30.1
//
//  Permet à EXO de démarrer même si des services
//  non critiques sont bloqués, lents ou en erreur.
//
//  Services critiques (forcés ON) :
//    orchestrator, stt, tts, vad, wakeword,
//    memory, nlu, context, planner, executor,
//    verifier, system
//
//  Services non critiques (lazy load) :
//    websearch, news, knowledge, tools,
//    networkmap, homegraph, domotic, camera,
//    voltalis, samsung, echo, fileservice, calendar
//
//  Déclenche safeBootReady quand les critiques sont prêts.
//  Les non-critiques continuent en arrière-plan.
// ═══════════════════════════════════════════════════════

class SafeBootManager : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(bool   safeBootActive    READ safeBootActive    NOTIFY safeBootChanged)
    Q_PROPERTY(bool   criticalReady     READ criticalReady     NOTIFY criticalReadyChanged)
    Q_PROPERTY(int    criticalTotal     READ criticalTotal     CONSTANT)
    Q_PROPERTY(int    criticalReadyCount READ criticalReadyCount NOTIFY criticalReadyChanged)
    Q_PROPERTY(int    lazyTotal         READ lazyTotal         CONSTANT)
    Q_PROPERTY(int    lazyReadyCount    READ lazyReadyCount    NOTIFY lazyProgressChanged)
    Q_PROPERTY(int    failedCount       READ failedCount       NOTIFY safeBootChanged)
    Q_PROPERTY(QVariantList failedServices  READ failedServices  NOTIFY safeBootChanged)
    Q_PROPERTY(QVariantList lazyServices    READ lazyServices    NOTIFY lazyProgressChanged)
    Q_PROPERTY(QVariantList criticalServices READ criticalServices NOTIFY criticalReadyChanged)

public:
    explicit SafeBootManager(QObject *parent = nullptr);

    void setRegistry(ServiceRegistry *registry);

    // ── Classification ──
    Q_INVOKABLE bool isCritical(const QString &name) const;

    // ── Accesseurs ──
    bool safeBootActive() const { return m_safeBootActive; }
    bool criticalReady() const;
    int  criticalTotal() const { return m_criticalServices.size(); }
    int  criticalReadyCount() const;
    int  lazyTotal() const;
    int  lazyReadyCount() const;
    int  failedCount() const;

    QVariantList failedServices() const;
    QVariantList lazyServices() const;
    QVariantList criticalServices() const;

    // ── Diagnostics ──
    Q_INVOKABLE QVariantMap diagnosticReport() const;

signals:
    void safeBootChanged();
    void criticalReadyChanged();
    void lazyProgressChanged();
    void safeBootReady();           // Tous les critiques sont prêts
    void allServicesNormalized();   // Tous les services (y compris lazy) sont prêts

public slots:
    void onServiceStateChanged(const QString &name, const QString &oldState, const QString &newState);

private:
    void checkCriticalReady();
    void checkAllNormalized();
    void activateSafeBoot(const QString &reason);

    ServiceRegistry *m_registry = nullptr;
    QSet<QString>    m_criticalServices;
    bool             m_safeBootActive = false;
    bool             m_criticalEmitted = false;

    static const QSet<QString> s_defaultCritical;
};
