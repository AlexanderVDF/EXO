#include "systemmonitor.h"
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QTextStream>
#include <QProcess>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>
#include <QDateTime>
#include <QCoreApplication>

SystemMonitor::SystemMonitor(QObject *parent)
    : QObject(parent)
    , m_cpuUsage(0.0)
    , m_memoryUsage(0.0)
    , m_temperature(0.0)
    , m_batteryLevel(100)
    , m_diskUsage(0.0)
    , m_networkRxBytes(0)
    , m_networkTxBytes(0)
    , m_isOnBattery(false)
    , m_updateInterval(5000)
{
    // Timer principal pour la mise à jour des métriques
    m_updateTimer = new QTimer(this);
    connect(m_updateTimer, &QTimer::timeout, this, &SystemMonitor::updateMetrics);
    
    // Timer pour monitoring réseau (plus fréquent)
    m_networkTimer = new QTimer(this);
    connect(m_networkTimer, &QTimer::timeout, this, &SystemMonitor::updateNetworkStats);
    
    // Surveillance des fichiers système (Linux/Raspberry Pi)
    m_fileWatcher = new QFileSystemWatcher(this);
    
    #ifdef Q_OS_LINUX
    // Fichiers à surveiller sur Linux/Raspberry Pi
    QStringList watchFiles = {
        "/proc/loadavg",
        "/proc/meminfo", 
        "/sys/class/thermal/thermal_zone0/temp",
        "/sys/class/power_supply/BAT0/capacity"
    };
    
    for (const QString& file : watchFiles) {
        if (QFile::exists(file)) {
            m_fileWatcher->addPath(file);
        }
    }
    
    connect(m_fileWatcher, &QFileSystemWatcher::fileChanged, 
            this, &SystemMonitor::onSystemFileChanged);
    #endif
    
    qDebug() << "SystemMonitor initialisé";
}

SystemMonitor::~SystemMonitor()
{
    stop();
}

void SystemMonitor::start()
{
    qDebug() << "Démarrage du monitoring système...";
    
    // Mise à jour initiale
    updateMetrics();
    
    // Démarrage des timers
    m_updateTimer->start(m_updateInterval);
    m_networkTimer->start(2000); // Réseau toutes les 2s
    
    emit monitoringStarted();
}

void SystemMonitor::stop()
{
    m_updateTimer->stop();
    m_networkTimer->stop();
    
    qDebug() << "Monitoring système arrêté";
    emit monitoringStopped();
}

void SystemMonitor::setUpdateInterval(int intervalMs)
{
    m_updateInterval = qMax(1000, intervalMs); // Minimum 1 seconde
    
    if (m_updateTimer->isActive()) {
        m_updateTimer->setInterval(m_updateInterval);
    }
    
    qDebug() << "Intervalle de monitoring ajusté à:" << m_updateInterval << "ms";
}

void SystemMonitor::updateMetrics()
{
    #ifdef Q_OS_WIN
    updateWindowsMetrics();
    #else
    updateLinuxMetrics();
    #endif
    
    emit metricsUpdated();
}

void SystemMonitor::updateWindowsMetrics()
{
    // Simulation pour Windows (développement)
    static int counter = 0;
    counter++;
    
    // CPU usage simulé
    double newCpuUsage = 15.0 + (counter % 20);
    if (qAbs(m_cpuUsage - newCpuUsage) > 0.5) {
        m_cpuUsage = newCpuUsage;
        emit cpuUsageChanged();
    }
    
    // Memory usage simulé  
    double newMemoryUsage = 45.0 + (counter % 15);
    if (qAbs(m_memoryUsage - newMemoryUsage) > 0.5) {
        m_memoryUsage = newMemoryUsage;
        emit memoryUsageChanged();
    }
    
    // Température simulée
    double newTemp = 45.0 + (counter % 10);
    if (qAbs(m_temperature - newTemp) > 0.5) {
        m_temperature = newTemp;
        emit temperatureChanged();
    }
    
    // Batterie simulée
    int newBattery = qMax(20, 100 - (counter % 80));
    if (m_batteryLevel != newBattery) {
        m_batteryLevel = newBattery;
        emit batteryLevelChanged();
        
        if (newBattery < 20) {
            emit lowBatteryWarning(newBattery);
        }
    }
    
    // Disk usage simulé
    double newDiskUsage = 35.0 + (counter % 25);
    if (qAbs(m_diskUsage - newDiskUsage) > 0.5) {
        m_diskUsage = newDiskUsage;
        emit diskUsageChanged();
    }
}

void SystemMonitor::updateLinuxMetrics()
{
    // CPU Usage
    updateCpuUsage();
    
    // Memory Usage
    updateMemoryUsage();
    
    // Temperature (Raspberry Pi)
    updateTemperature();
    
    // Battery Level
    updateBatteryLevel();
    
    // Disk Usage
    updateDiskUsage();
}

void SystemMonitor::updateCpuUsage()
{
    QFile file("/proc/loadavg");
    if (file.open(QIODevice::ReadOnly)) {
        QString content = file.readAll().trimmed();
        QStringList parts = content.split(' ');
        
        if (!parts.isEmpty()) {
            bool ok;
            double load1min = parts[0].toDouble(&ok);
            if (ok) {
                // Conversion approximative load average -> pourcentage CPU
                double newCpuUsage = qMin(100.0, load1min * 25.0);
                
                if (qAbs(m_cpuUsage - newCpuUsage) > 0.5) {
                    m_cpuUsage = newCpuUsage;
                    emit cpuUsageChanged();
                    
                    if (newCpuUsage > 80.0) {
                        emit highCpuUsage(newCpuUsage);
                    }
                }
            }
        }
        file.close();
    }
}

void SystemMonitor::updateMemoryUsage()
{
    QFile file("/proc/meminfo");
    if (file.open(QIODevice::ReadOnly)) {
        QTextStream stream(&file);
        QString line;
        
        long totalMem = 0;
        long availableMem = 0;
        
        while (stream.readLineInto(&line)) {
            if (line.startsWith("MemTotal:")) {
                totalMem = line.split(QRegularExpression("\\s+"))[1].toLong();
            } else if (line.startsWith("MemAvailable:")) {
                availableMem = line.split(QRegularExpression("\\s+"))[1].toLong();
                break;
            }
        }
        
        if (totalMem > 0 && availableMem > 0) {
            double newMemoryUsage = ((double)(totalMem - availableMem) / totalMem) * 100.0;
            
            if (qAbs(m_memoryUsage - newMemoryUsage) > 0.5) {
                m_memoryUsage = newMemoryUsage;
                emit memoryUsageChanged();
                
                if (newMemoryUsage > 90.0) {
                    emit highMemoryUsage(newMemoryUsage);
                }
            }
        }
        file.close();
    }
}

void SystemMonitor::updateTemperature()
{
    // Raspberry Pi thermal zone
    QFile file("/sys/class/thermal/thermal_zone0/temp");
    if (file.open(QIODevice::ReadOnly)) {
        QString content = file.readAll().trimmed();
        bool ok;
        int tempMilliCelsius = content.toInt(&ok);
        
        if (ok) {
            double newTemp = tempMilliCelsius / 1000.0;
            
            if (qAbs(m_temperature - newTemp) > 0.5) {
                m_temperature = newTemp;
                emit temperatureChanged();
                
                if (newTemp > 70.0) {
                    emit overheatingWarning(newTemp);
                }
            }
        }
        file.close();
    }
}

void SystemMonitor::updateBatteryLevel()
{
    QFile file("/sys/class/power_supply/BAT0/capacity");
    if (file.open(QIODevice::ReadOnly)) {
        QString content = file.readAll().trimmed();
        bool ok;
        int newBattery = content.toInt(&ok);
        
        if (ok && m_batteryLevel != newBattery) {
            m_batteryLevel = newBattery;
            emit batteryLevelChanged();
            
            if (newBattery <= 15 && !m_isOnBattery) {
                emit lowBatteryWarning(newBattery);
            }
        }
        file.close();
        
        // Vérifier si on est sur batterie
        QFile statusFile("/sys/class/power_supply/BAT0/status");
        if (statusFile.open(QIODevice::ReadOnly)) {
            QString status = statusFile.readAll().trimmed();
            bool onBattery = (status == "Discharging");
            
            if (m_isOnBattery != onBattery) {
                m_isOnBattery = onBattery;
                emit batteryStatusChanged(onBattery);
            }
            statusFile.close();
        }
    }
}

void SystemMonitor::updateDiskUsage()
{
    QProcess df;
    df.start("df", QStringList() << "-h" << "/");
    df.waitForFinished(3000);
    
    QString output = df.readAllStandardOutput();
    QStringList lines = output.split('\n');
    
    if (lines.size() >= 2) {
        QStringList parts = lines[1].split(QRegularExpression("\\s+"));
        if (parts.size() >= 5) {
            QString usageStr = parts[4];
            if (usageStr.endsWith('%')) {
                usageStr.chop(1);
                bool ok;
                double newDiskUsage = usageStr.toDouble(&ok);
                
                if (ok && qAbs(m_diskUsage - newDiskUsage) > 0.5) {
                    m_diskUsage = newDiskUsage;
                    emit diskUsageChanged();
                    
                    if (newDiskUsage > 85.0) {
                        emit lowDiskSpace(newDiskUsage);
                    }
                }
            }
        }
    }
}

void SystemMonitor::updateNetworkStats()
{
    QFile file("/proc/net/dev");
    if (file.open(QIODevice::ReadOnly)) {
        QTextStream stream(&file);
        QString line;
        
        // Ignorer les deux premières lignes d'en-tête
        stream.readLine();
        stream.readLine();
        
        quint64 totalRx = 0, totalTx = 0;
        
        while (stream.readLineInto(&line)) {
            QStringList parts = line.split(QRegularExpression("\\s+"));
            if (parts.size() >= 10) {
                QString interface = parts[0];
                if (interface.endsWith(':')) {
                    interface.chop(1);
                }
                
                // Ignorer loopback
                if (interface != "lo") {
                    totalRx += parts[1].toULongLong();
                    totalTx += parts[9].toULongLong();
                }
            }
        }
        
        // Calculer le débit si ce n'est pas la première mesure
        if (m_networkRxBytes > 0) {
            double rxRate = (totalRx - m_networkRxBytes) / 2.0; // bytes/sec (timer = 2s)
            double txRate = (totalTx - m_networkTxBytes) / 2.0;
            
            emit networkActivity(rxRate, txRate);
        }
        
        m_networkRxBytes = totalRx;
        m_networkTxBytes = totalTx;
        
        file.close();
    }
}

void SystemMonitor::onSystemFileChanged(const QString& path)
{
    // Mise à jour immédiate si un fichier système change
    Q_UNUSED(path)
    updateMetrics();
}

QJsonObject SystemMonitor::getSystemInfo() const
{
    QJsonObject info;
    info["cpuUsage"] = m_cpuUsage;
    info["memoryUsage"] = m_memoryUsage;
    info["temperature"] = m_temperature;
    info["batteryLevel"] = m_batteryLevel;
    info["diskUsage"] = m_diskUsage;
    info["isOnBattery"] = m_isOnBattery;
    info["timestamp"] = QDateTime::currentSecsSinceEpoch();
    
    return info;
}