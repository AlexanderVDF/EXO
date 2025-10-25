#include "aimemorymanager.h"
#include <QDebug>
#include <QDateTime>

AIMemoryManager::AIMemoryManager(QObject *parent)
    : QObject(parent)
    , m_memoryEnabled(true)
    , m_conversationHistory()
    , m_userPreferences()
{
    qDebug() << "AIMemoryManager initialisé";
}

AIMemoryManager::~AIMemoryManager()
{
    saveMemoryToFile();
}

void AIMemoryManager::setMemoryEnabled(bool enabled)
{
    if (m_memoryEnabled != enabled) {
        m_memoryEnabled = enabled;
        emit memoryEnabledChanged();
        
        if (!enabled) {
            clearAllMemory();
        }
        
        qDebug() << "Mémoire IA" << (enabled ? "activée" : "désactivée");
    }
}

void AIMemoryManager::addConversation(const QString& userInput, const QString& aiResponse)
{
    if (!m_memoryEnabled) {
        return;
    }
    
    ConversationEntry entry;
    entry.timestamp = QDateTime::currentDateTime();
    entry.userInput = userInput;
    entry.aiResponse = aiResponse;
    
    m_conversationHistory.append(entry);
    
    // Limiter l'historique à 1000 entrées
    if (m_conversationHistory.size() > 1000) {
        m_conversationHistory.removeFirst();
    }
    
    emit conversationAdded(userInput, aiResponse);
    qDebug() << "Conversation ajoutée à la mémoire";
}

void AIMemoryManager::updateUserPreference(const QString& key, const QVariant& value)
{
    if (!m_memoryEnabled) {
        return;
    }
    
    m_userPreferences[key] = value;
    emit userPreferenceUpdated(key, value);
    
    qDebug() << "Préférence utilisateur mise à jour:" << key << "=" << value;
}

QVariant AIMemoryManager::getUserPreference(const QString& key, const QVariant& defaultValue) const
{
    return m_userPreferences.value(key, defaultValue);
}

QStringList AIMemoryManager::getRecentConversations(int count) const
{
    QStringList recent;
    int start = qMax(0, m_conversationHistory.size() - count);
    
    for (int i = start; i < m_conversationHistory.size(); ++i) {
        const auto& entry = m_conversationHistory[i];
        recent << QString("User: %1 | AI: %2").arg(entry.userInput, entry.aiResponse);
    }
    
    return recent;
}

QString AIMemoryManager::getContextForAI() const
{
    if (!m_memoryEnabled || m_conversationHistory.isEmpty()) {
        return QString();
    }
    
    QString context = "Contexte des conversations récentes:\n";
    
    // Ajouter les 5 dernières conversations
    int start = qMax(0, m_conversationHistory.size() - 5);
    for (int i = start; i < m_conversationHistory.size(); ++i) {
        const auto& entry = m_conversationHistory[i];
        context += QString("- %1: User: %2 | AI: %3\n")
                    .arg(entry.timestamp.toString("hh:mm"), 
                         entry.userInput.left(100),
                         entry.aiResponse.left(100));
    }
    
    // Ajouter les préférences importantes
    if (!m_userPreferences.isEmpty()) {
        context += "\nPréférences utilisateur:\n";
        auto it = m_userPreferences.constBegin();
        while (it != m_userPreferences.constEnd()) {
            context += QString("- %1: %2\n").arg(it.key(), it.value().toString());
            ++it;
        }
    }
    
    return context;
}

void AIMemoryManager::clearAllMemory()
{
    m_conversationHistory.clear();
    m_userPreferences.clear();
    
    emit memoryCleared();
    qDebug() << "Mémoire IA effacée";
}

void AIMemoryManager::clearConversationHistory()
{
    m_conversationHistory.clear();
    emit conversationHistoryCleared();
    qDebug() << "Historique des conversations effacé";
}

void AIMemoryManager::saveMemoryToFile()
{
    if (!m_memoryEnabled) {
        return;
    }
    
    qDebug() << "Sauvegarde de la mémoire IA...";
    
    // Simulation de sauvegarde
    emit memorySaved();
}

void AIMemoryManager::loadMemoryFromFile()
{
    if (!m_memoryEnabled) {
        return;
    }
    
    qDebug() << "Chargement de la mémoire IA...";
    
    // Simulation de chargement
    emit memoryLoaded();
}