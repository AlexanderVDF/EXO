#pragma once

#include <QObject>
#include <QTimer>
#include <QProcess>
#include <QFileSystemWatcher>

/**
 * @brief Monitoring système pour Raspberry Pi
 * 
 * Surveille CPU, mémoire, température, batterie et autres métriques système.
 * Optimisé pour les ressources limitées du Raspberry Pi 5.
 */
class SystemMonitor : public QObject
{
    Q_OBJECT
    Q_PROPERTY(double cpuUsage READ cpuUsage NOTIFY cpuUsageChanged)
    Q_PROPERTY(double memoryUsage READ memoryUsage NOTIFY memoryUsageChanged)
    Q_PROPERTY(double temperature READ temperature NOTIFY temperatureChanged)
    Q_PROPERTY(int batteryLevel READ batteryLevel NOTIFY batteryLevelChanged)
    Q_PROPERTY(double diskUsage READ diskUsage NOTIFY diskUsageChanged)

public:
    explicit SystemMonitor(QObject *parent = nullptr);
    ~SystemMonitor();

    // Propriétés système
    double cpuUsage() const { return m_cpuUsage; }
    double memoryUsage() const { return m_memoryUsage; }
    double temperature() const { return m_temperature; }
    int batteryLevel() const { return m_batteryLevel; }
    double diskUsage() const { return m_diskUsage; }

    // Informations système
    QString getSystemInfo() const;
    QString getHardwareInfo() const;

public slots:
    void updateStats();
    void startMonitoring(int intervalMs = 2000);
    void stopMonitoring();
    void resetStats();

signals:
    void statsUpdated();
    void cpuUsageChanged(double usage);
    void memoryUsageChanged(double usage);
    void temperatureChanged(double temp);
    void batteryLevelChanged(int level);
    void diskUsageChanged(double usage);
    void highTemperatureWarning(double temp);
    void lowBatteryWarning(int level);

private slots:
    void collectSystemStats();
    void checkTemperature();
    void checkBatteryLevel();

private:
    void initializeMonitoring();
    double readCpuUsage();
    double readMemoryUsage();
    double readTemperature();
    int readBatteryLevel();
    double readDiskUsage();
    
    QTimer* m_updateTimer;
    QFileSystemWatcher* m_fileWatcher;
    
    // Métriques système
    double m_cpuUsage;
    double m_memoryUsage;
    double m_temperature;
    int m_batteryLevel;
    double m_diskUsage;
    
    // Seuils d'alerte
    static constexpr double HIGH_TEMP_THRESHOLD = 75.0;
    static constexpr int LOW_BATTERY_THRESHOLD = 15;
    
    // Historique pour calculs
    quint64 m_lastCpuIdle;
    quint64 m_lastCpuTotal;
    
    bool m_isMonitoring;
};