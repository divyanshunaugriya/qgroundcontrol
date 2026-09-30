#include "QGroundControlQmlGlobal.h"

#include "QGCCorePlugin.h"
#include "LinkManager.h"
#include "MAVLinkProtocol.h"
#include "FirmwarePluginManager.h"
#include "AppSettings.h"
#include "FlightMapSettings.h"
#include "SettingsManager.h"
#include "PositionManager.h"
#include "QGCMapEngineManager.h"
#include "ADSBVehicleManager.h"
#include "AudioOutput.h"
#include "NTRIPManager.h"
#include "MAVLinkSigningKeys.h"
#include "MissionCommandTree.h"
#include "VideoManager.h"
#include "MultiVehicleManager.h"
#include "LoggingCategoryModel.h"
#ifndef QGC_NO_SERIAL_LINK
#include "GPSManager.h"
#include "GPSRtk.h"
#endif
#ifdef QT_DEBUG
#include "MockLink.h"
#endif

#include <QtCore/QDir>
#include <QtCore/QFile>
#include <QtCore/QLineF>
#include <QtCore/QSettings>
#include <QtCore/QStandardPaths>
#include <QtCore/QSysInfo>
#include <QtCore/QUrl>
#include <QtGui/QClipboard>
#include <QtGui/QGuiApplication>
#include <QtNetwork/QNetworkAccessManager>
#include <QtNetwork/QNetworkReply>
#include <QtNetwork/QNetworkRequest>

#ifdef Q_OS_ANDROID
#include <QtCore/QJniEnvironment>
#include <QtCore/QJniObject>
#endif

#include "qgc_version.h"

#include "QGCGeo.h"
#include "QGCLoggingCategory.h"

#include <cmath>

QGC_LOGGING_CATEGORY(GuidedActionsControllerLog, "QMLControls.GuidedActionsController")

QGeoCoordinate QGroundControlQmlGlobal::_coord = QGeoCoordinate(0.0,0.0);
double QGroundControlQmlGlobal::_zoom = 2;

QGroundControlQmlGlobal::QGroundControlQmlGlobal(QObject *parent)
    : QObject(parent)
    , _mapEngineManager(QGCMapEngineManager::instance())
    , _adsbVehicleManager(ADSBVehicleManager::instance())
    , _ntripManager(NTRIPManager::instance())
    , _qgcPositionManager(QGCPositionManager::instance())
    , _missionCommandTree(MissionCommandTree::instance())
    , _mavlinkSigningKeys(MAVLinkSigningKeys::instance())
    , _videoManager(VideoManager::instance())
    , _linkManager(LinkManager::instance())
    , _multiVehicleManager(MultiVehicleManager::instance())
    , _settingsManager(SettingsManager::instance())
    , _corePlugin(QGCCorePlugin::instance())
    , _globalPalette(new QGCPalette(this))
#ifndef QGC_NO_SERIAL_LINK
    , _gpsRtkFactGroup(GPSManager::instance()->gpsRtk()->gpsRtkFactGroup())
#endif
{
    // We clear the parent on this object since we run into shutdown problems caused by hybrid qml app. Instead we let it leak on shutdown.
    // setParent(nullptr);

    // Load last coordinates and zoom from config file
    QSettings settings;
    settings.beginGroup(_flightMapPositionSettingsGroup);
    _coord.setLatitude(settings.value(_flightMapPositionLatitudeSettingsKey,    _coord.latitude()).toDouble());
    _coord.setLongitude(settings.value(_flightMapPositionLongitudeSettingsKey,  _coord.longitude()).toDouble());
    _zoom = settings.value(_flightMapZoomSettingsKey, _zoom).toDouble();
    _flightMapPositionSettledTimer.setSingleShot(true);
    _flightMapPositionSettledTimer.setInterval(1000);
    (void) connect(&_flightMapPositionSettledTimer, &QTimer::timeout, this, []() {
        // When they settle, save flightMapPosition and Zoom to the config file
        QSettings settingsInner;
        settingsInner.beginGroup(_flightMapPositionSettingsGroup);
        settingsInner.setValue(_flightMapPositionLatitudeSettingsKey, _coord.latitude());
        settingsInner.setValue(_flightMapPositionLongitudeSettingsKey, _coord.longitude());
        settingsInner.setValue(_flightMapZoomSettingsKey, _zoom);
    });
    connect(this, &QGroundControlQmlGlobal::flightMapPositionChanged, this, [this](QGeoCoordinate){
        if (!_flightMapPositionSettledTimer.isActive()) {
            _flightMapPositionSettledTimer.start();
        }
    });
    connect(this, &QGroundControlQmlGlobal::flightMapZoomChanged, this, [this](double){
        if (!_flightMapPositionSettledTimer.isActive()) {
            _flightMapPositionSettledTimer.start();
        }
    });
}

QGroundControlQmlGlobal::~QGroundControlQmlGlobal()
{
}

void QGroundControlQmlGlobal::saveGlobalSetting (const QString& key, const QString& value)
{
    QSettings settings;
    settings.beginGroup(kQmlGlobalKeyName);
    settings.setValue(key, value);
}

QString QGroundControlQmlGlobal::loadGlobalSetting (const QString& key, const QString& defaultValue)
{
    QSettings settings;
    settings.beginGroup(kQmlGlobalKeyName);
    return settings.value(key, defaultValue).toString();
}

void QGroundControlQmlGlobal::saveBoolGlobalSetting (const QString& key, bool value)
{
    QSettings settings;
    settings.beginGroup(kQmlGlobalKeyName);
    settings.setValue(key, value);
}

bool QGroundControlQmlGlobal::loadBoolGlobalSetting (const QString& key, bool defaultValue)
{
    QSettings settings;
    settings.beginGroup(kQmlGlobalKeyName);
    return settings.value(key, defaultValue).toBool();
}

#ifdef QT_DEBUG
static MockConfiguration::Options _mockLinkOptions(bool sendStatusText, bool enableCamera, bool enableGimbal, bool enableProximity, bool apmStartFreshParams = false)
{
    MockConfiguration::Options options = MockConfiguration::OptionNone;
    options.setFlag(MockConfiguration::OptionSendStatusText, sendStatusText);
    options.setFlag(MockConfiguration::OptionEnableCamera, enableCamera);
    options.setFlag(MockConfiguration::OptionEnableGimbal, enableGimbal);
    options.setFlag(MockConfiguration::OptionEnableProximity, enableProximity);
    options.setFlag(MockConfiguration::OptionAPMStartFreshParams, apmStartFreshParams);
    return options;
}
#endif

void QGroundControlQmlGlobal::startPX4MockLink(bool sendStatusText, bool enableCamera, bool enableGimbal, bool enableProximity, int videoStreamType)
{
#ifdef QT_DEBUG
    MockLink::startPX4MockLink(_mockLinkOptions(sendStatusText, enableCamera, enableGimbal, enableProximity), MockConfiguration::FailNone, MockConfiguration::videoStreamTypeFromInt(videoStreamType));
#else
    Q_UNUSED(sendStatusText);
    Q_UNUSED(enableCamera);
    Q_UNUSED(enableGimbal);
    Q_UNUSED(enableProximity);
    Q_UNUSED(videoStreamType);
#endif
}

void QGroundControlQmlGlobal::startGenericMockLink(bool sendStatusText, bool enableCamera, bool enableGimbal, bool enableProximity, int videoStreamType)
{
#ifdef QT_DEBUG
    MockLink::startGenericMockLink(_mockLinkOptions(sendStatusText, enableCamera, enableGimbal, enableProximity), MockConfiguration::FailNone, MockConfiguration::videoStreamTypeFromInt(videoStreamType));
#else
    Q_UNUSED(sendStatusText);
    Q_UNUSED(enableCamera);
    Q_UNUSED(enableGimbal);
    Q_UNUSED(enableProximity);
    Q_UNUSED(videoStreamType);
#endif
}

void QGroundControlQmlGlobal::startAPMArduCopterMockLink(bool sendStatusText, bool enableCamera, bool enableGimbal, bool enableProximity, bool apmStartFreshParams, int videoStreamType)
{
#ifdef QT_DEBUG
    MockLink::startAPMArduCopterMockLink(_mockLinkOptions(sendStatusText, enableCamera, enableGimbal, enableProximity, apmStartFreshParams), MockConfiguration::FailNone, MockConfiguration::videoStreamTypeFromInt(videoStreamType));
#else
    Q_UNUSED(sendStatusText);
    Q_UNUSED(enableCamera);
    Q_UNUSED(enableGimbal);
    Q_UNUSED(enableProximity);
    Q_UNUSED(apmStartFreshParams);
    Q_UNUSED(videoStreamType);
#endif
}

void QGroundControlQmlGlobal::startAPMArduPlaneMockLink(bool sendStatusText, bool enableCamera, bool enableGimbal, bool enableProximity, bool apmStartFreshParams, int videoStreamType)
{
#ifdef QT_DEBUG
    MockLink::startAPMArduPlaneMockLink(_mockLinkOptions(sendStatusText, enableCamera, enableGimbal, enableProximity, apmStartFreshParams), MockConfiguration::FailNone, MockConfiguration::videoStreamTypeFromInt(videoStreamType));
#else
    Q_UNUSED(sendStatusText);
    Q_UNUSED(enableCamera);
    Q_UNUSED(enableGimbal);
    Q_UNUSED(enableProximity);
    Q_UNUSED(apmStartFreshParams);
    Q_UNUSED(videoStreamType);
#endif
}

void QGroundControlQmlGlobal::startAPMArduSubMockLink(bool sendStatusText, bool enableCamera, bool enableGimbal, bool enableProximity, bool apmStartFreshParams, int videoStreamType)
{
#ifdef QT_DEBUG
    MockLink::startAPMArduSubMockLink(_mockLinkOptions(sendStatusText, enableCamera, enableGimbal, enableProximity, apmStartFreshParams), MockConfiguration::FailNone, MockConfiguration::videoStreamTypeFromInt(videoStreamType));
#else
    Q_UNUSED(sendStatusText);
    Q_UNUSED(enableCamera);
    Q_UNUSED(enableGimbal);
    Q_UNUSED(enableProximity);
    Q_UNUSED(apmStartFreshParams);
    Q_UNUSED(videoStreamType);
#endif
}

void QGroundControlQmlGlobal::startAPMArduRoverMockLink(bool sendStatusText, bool enableCamera, bool enableGimbal, bool enableProximity, bool apmStartFreshParams, int videoStreamType)
{
#ifdef QT_DEBUG
    MockLink::startAPMArduRoverMockLink(_mockLinkOptions(sendStatusText, enableCamera, enableGimbal, enableProximity, apmStartFreshParams), MockConfiguration::FailNone, MockConfiguration::videoStreamTypeFromInt(videoStreamType));
#else
    Q_UNUSED(sendStatusText);
    Q_UNUSED(enableCamera);
    Q_UNUSED(enableGimbal);
    Q_UNUSED(enableProximity);
    Q_UNUSED(apmStartFreshParams);
    Q_UNUSED(videoStreamType);
#endif
}

void QGroundControlQmlGlobal::stopOneMockLink(void)
{
#ifdef QT_DEBUG
    QList<SharedLinkInterfacePtr> sharedLinks = LinkManager::instance()->links();

    for (int i=0; i<sharedLinks.count(); i++) {
        LinkInterface* link = sharedLinks[i].get();
        MockLink* mockLink = qobject_cast<MockLink*>(link);
        if (mockLink) {
            mockLink->disconnect();
            return;
        }
    }
#endif
}

bool QGroundControlQmlGlobal::singleFirmwareSupport(void)
{
    return FirmwarePluginManager::instance()->singleFirmwareSupport();
}

bool QGroundControlQmlGlobal::singleVehicleSupport(void)
{
    return FirmwarePluginManager::instance()->singleVehicleSupport();
}

bool QGroundControlQmlGlobal::px4ProFirmwareSupported()
{
    return FirmwarePluginManager::instance()->firmwareClassSupported(QGCMAVLink::FirmwareClassPX4);
}

bool QGroundControlQmlGlobal::apmFirmwareSupported()
{
    return FirmwarePluginManager::instance()->firmwareClassSupported(QGCMAVLink::FirmwareClassArduPilot);
}

bool QGroundControlQmlGlobal::linesIntersect(QPointF line1A, QPointF line1B, QPointF line2A, QPointF line2B)
{
    QPointF intersectPoint;

    auto intersect = QLineF(line1A, line1B).intersects(QLineF(line2A, line2B), &intersectPoint);

    return  intersect == QLineF::BoundedIntersection &&
            intersectPoint != line1A && intersectPoint != line1B;
}

void QGroundControlQmlGlobal::setFlightMapPosition(QGeoCoordinate& coordinate)
{
    if (coordinate != flightMapPosition()) {
        _coord.setLatitude(coordinate.latitude());
        _coord.setLongitude(coordinate.longitude());
        emit flightMapPositionChanged(coordinate);
    }
}

void QGroundControlQmlGlobal::setFlightMapZoom(double zoom)
{
    if (zoom != flightMapZoom()) {
        _zoom = zoom;
        emit flightMapZoomChanged(zoom);
    }
}

QString QGroundControlQmlGlobal::qgcVersion(void)
{
    QString versionStr = QCoreApplication::applicationVersion();
    if(QSysInfo::buildAbi().contains("32"))
    {
        versionStr += QStringLiteral(" %1").arg(tr("32 bit"));
    }
    else if(QSysInfo::buildAbi().contains("64"))
    {
        versionStr += QStringLiteral(" %1").arg(tr("64 bit"));
    }
    return versionStr;
}

QString QGroundControlQmlGlobal::qgcAppDate()
{
    return QGC_APP_DATE;
}

QString QGroundControlQmlGlobal::altitudeFrameExtraUnits(AltitudeFrame altFrame)
{
    switch (altFrame) {
    case AltitudeFrameNone:
        return QString();
    case AltitudeFrameRelative:
        return tr("Rel");
    case AltitudeFrameAbsolute:
        return tr("AMSL");
    case AltitudeFrameCalcAboveTerrain:
        return tr("AGLC");
    case AltitudeFrameTerrain:
        return tr("AGL");
    case AltitudeFrameMixed:
        return tr("Mixed");
    }

    // Should never get here but makes some compilers happy
    return QString();
}

QString QGroundControlQmlGlobal::altitudeFrameShortDescription(AltitudeFrame altFrame)
{
    switch (altFrame) {
    case AltitudeFrameNone:
        return QString();
    case AltitudeFrameRelative:
        return tr("Relative (%1)").arg(altitudeFrameExtraUnits(altFrame));
    case AltitudeFrameAbsolute:
        return tr("Absolute (%1)").arg(altitudeFrameExtraUnits(altFrame));
    case AltitudeFrameCalcAboveTerrain:
        return tr("Above Terrain Calced (%1)").arg(altitudeFrameExtraUnits(altFrame));
    case AltitudeFrameTerrain:
        return tr("Above Terrain (%1)").arg(altitudeFrameExtraUnits(altFrame));
    case AltitudeFrameMixed:
        return tr("Mixed");
    }

    // Should never get here but makes some compilers happy
    return QString();
}

void QGroundControlQmlGlobal::showMessageDialog(
    QObject* owner,
    const QString& title,
    const QString& text,
    int buttons,
    QJSValue acceptFunction,
    QJSValue closeFunction)
{
    emit showMessageDialogRequested(owner, title, text, buttons, acceptFunction, closeFunction);
}

void QGroundControlQmlGlobal::testAudioOutput()
{
    AudioOutput::instance()->testAudioOutput();
}

void QGroundControlQmlGlobal::copyToClipboard(const QString& text)
{
    QGuiApplication::clipboard()->setText(text);
}

QString QGroundControlQmlGlobal::coordinateToMGRS(const QGeoCoordinate& coord)
{
    if (!coord.isValid() || std::isnan(coord.latitude()) || std::isnan(coord.longitude())) {
        return QString();
    }
    return QGCGeo::convertGeoToMGRS(coord);
}

QString QGroundControlQmlGlobal::coordinateToFormattedLatLon(const QGeoCoordinate& coord, int decimalPlaces)
{
    if (!coord.isValid() || std::isnan(coord.latitude()) || std::isnan(coord.longitude())) {
        return QString();
    }
    const double lat = coord.latitude();
    const double lon = coord.longitude();
    const QChar latDir = (lat >= 0.0) ? QLatin1Char('N') : QLatin1Char('S');
    const QChar lonDir = (lon >= 0.0) ? QLatin1Char('E') : QLatin1Char('W');
    return QStringLiteral("%1° %2, %3° %4")
        .arg(QString::number(std::abs(lat), 'f', decimalPlaces))
        .arg(latDir)
        .arg(QString::number(std::abs(lon), 'f', decimalPlaces))
        .arg(lonDir);
}

void QGroundControlQmlGlobal::setCoordinateDisplayMode(int mode)
{
    if (mode < 0 || mode > 2) {
        mode = CoordinateDisplayBoth;
    }
    if (_coordinateDisplayMode != mode) {
        _coordinateDisplayMode = mode;
        QSettings settings;
        settings.setValue(QStringLiteral("IRSCoordinateDisplayMode"), _coordinateDisplayMode);
        emit coordinateDisplayModeChanged(_coordinateDisplayMode);
    }
}

void QGroundControlQmlGlobal::cycleCoordinateDisplayMode()
{
    setCoordinateDisplayMode((_coordinateDisplayMode + 1) % 3);
}

QString QGroundControlQmlGlobal::coordinateDisplayModeName() const
{
    switch (_coordinateDisplayMode) {
    case CoordinateDisplayLatLon: return QStringLiteral("LAT / LON");
    case CoordinateDisplayGR:     return QStringLiteral("GR");
    case CoordinateDisplayBoth:   return QStringLiteral("BOTH");
    default:                      return QStringLiteral("BOTH");
    }
}

QString QGroundControlQmlGlobal::formatCoordinate(const QGeoCoordinate& coord) const
{
    if (!coord.isValid() || std::isnan(coord.latitude()) || std::isnan(coord.longitude())) {
        return QStringLiteral("--");
    }
    const QString latLon = coordinateToFormattedLatLon(coord, 6);
    const QString gr = coordinateToMGRS(coord);

    switch (_coordinateDisplayMode) {
    case CoordinateDisplayLatLon:
        return latLon;
    case CoordinateDisplayGR:
        return gr.isEmpty() ? latLon : (QStringLiteral("GR: ") + gr);
    case CoordinateDisplayBoth:
    default:
        return gr.isEmpty() ? latLon : (latLon + QStringLiteral("  |  GR: ") + gr);
    }
}

QString QGroundControlQmlGlobal::elevationProviderName()
{
    return _settingsManager->flightMapSettings()->elevationMapProvider()->rawValue().toString();
}

QString QGroundControlQmlGlobal::elevationProviderNotice()
{
    return _settingsManager->flightMapSettings()->elevationMapProvider()->rawValue().toString();
}

QString QGroundControlQmlGlobal::parameterFileExtension() const
{
    return AppSettings::parameterFileExtension;
}

QString QGroundControlQmlGlobal::telemetryFileExtension() const
{
    return AppSettings::telemetryFileExtension;
}

QString QGroundControlQmlGlobal::appName()
{
    return QCoreApplication::applicationName();
}

QString QGroundControlQmlGlobal::machineUniqueId()
{
    QByteArray id = QSysInfo::machineUniqueId();
    if (id.isEmpty()) {
        id = QSysInfo::bootUniqueId();
    }
    if (id.isEmpty()) {
        id = QSysInfo::machineHostName().toUtf8();
    }
    return QString::fromLatin1(id.toHex().toUpper());
}

void QGroundControlQmlGlobal::cancelAppUpdate()
{
    if (_updateReply) {
        _updateReply->abort();
        _updateReply->deleteLater();
        _updateReply = nullptr;
    }
    if (_updateFile) {
        if (_updateFile->isOpen()) {
            _updateFile->close();
        }
        delete _updateFile;
        _updateFile = nullptr;
    }
}

void QGroundControlQmlGlobal::startAppUpdate(const QString& assetApiUrl, const QString& token)
{
    cancelAppUpdate();

    if (!_updateNetMgr) {
        _updateNetMgr = new QNetworkAccessManager(this);
    }

    QString targetDir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation);
    if (targetDir.isEmpty()) {
        targetDir = QStandardPaths::writableLocation(QStandardPaths::TempLocation);
    }
    QDir().mkpath(targetDir);
    QString targetFilePath = QDir(targetDir).filePath(QStringLiteral("IRS_Alex_GCS_update.apk"));

    QFile::remove(targetFilePath);

    _updateFile = new QFile(targetFilePath, this);
    if (!_updateFile->open(QIODevice::WriteOnly)) {
        emit appUpdateError(QStringLiteral("Cannot create temporary update file: %1").arg(_updateFile->errorString()));
        delete _updateFile;
        _updateFile = nullptr;
        return;
    }

    _updateLastBytes = 0;
    _updateLastTimeMs = 0;
    _updateTimer.restart();

    QUrl initialUrl(assetApiUrl.trimmed());
    _startDownloadReply(initialUrl, !token.isEmpty(), token, targetFilePath);
}

void QGroundControlQmlGlobal::_startDownloadReply(const QUrl& url, bool withAuth, const QString& token, const QString& filePath)
{
    QNetworkRequest request(url);
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::ManualRedirectPolicy);
    request.setRawHeader("User-Agent", "IRS-AlexGCS-Updater");
    request.setRawHeader("Accept", "application/octet-stream");

    if (withAuth && !token.isEmpty()) {
        request.setRawHeader("Authorization", QStringLiteral("Bearer %1").arg(token).toUtf8());
    }

    _updateReply = _updateNetMgr->get(request);

    connect(_updateReply, &QNetworkReply::downloadProgress, this, [this](qint64 bytesReceived, qint64 bytesTotal) {
        qint64 currentElapsed = _updateTimer.elapsed();
        qint64 deltaMs = currentElapsed - _updateLastTimeMs;
        qint64 speed = 0;
        if (deltaMs >= 500) {
            qint64 deltaBytes = bytesReceived - _updateLastBytes;
            if (deltaMs > 0) {
                speed = (deltaBytes * 1000) / deltaMs;
            }
            _updateLastBytes = bytesReceived;
            _updateLastTimeMs = currentElapsed;
        }
        emit appUpdateProgress(bytesReceived, bytesTotal, speed);
    });

    connect(_updateReply, &QNetworkReply::readyRead, this, [this]() {
        if (_updateReply && _updateFile && _updateFile->isOpen()) {
            _updateFile->write(_updateReply->readAll());
        }
    });

    connect(_updateReply, &QNetworkReply::finished, this, [this, token, filePath]() {
        if (!_updateReply) return;

        QNetworkReply* reply = _updateReply;
        _updateReply = nullptr;
        reply->deleteLater();

        if (reply->error() == QNetworkReply::OperationCanceledError) {
            if (_updateFile && _updateFile->isOpen()) {
                _updateFile->close();
            }
            return;
        }

        int statusCode = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        QVariant redirectVar = reply->attribute(QNetworkRequest::RedirectionTargetAttribute);

        if (statusCode >= 300 && statusCode < 400 && !redirectVar.isNull()) {
            QUrl redirectUrl = reply->url().resolved(redirectVar.toUrl());
            // Follow redirect without Auth header (Azure / AWS S3 does not allow Authorization header)
            _startDownloadReply(redirectUrl, false, QString(), filePath);
            return;
        }

        if (reply->error() != QNetworkReply::NoError) {
            if (_updateFile && _updateFile->isOpen()) {
                _updateFile->close();
            }
            emit appUpdateError(QStringLiteral("Download failed: %1 (HTTP %2)").arg(reply->errorString()).arg(statusCode));
            return;
        }

        if (_updateFile && _updateFile->isOpen()) {
            _updateFile->write(reply->readAll());
            _updateFile->flush();
            _updateFile->close();
        }

        emit appUpdateFinished(filePath);

#ifdef Q_OS_ANDROID
        QJniObject jFilePath = QJniObject::fromString(filePath);
        QJniObject::callStaticMethod<void>(
            "org/mavlink/qgroundcontrol/QGCActivity",
            "installApk",
            "(Ljava/lang/String;)V",
            jFilePath.object<jstring>()
        );
#endif
    });
}

void QGroundControlQmlGlobal::installDownloadedApk()
{
    QString targetDir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation);
    if (targetDir.isEmpty()) {
        targetDir = QStandardPaths::writableLocation(QStandardPaths::TempLocation);
    }
    QString targetFilePath = QDir(targetDir).filePath(QStringLiteral("IRS_Alex_GCS_update.apk"));
    if (!QFile::exists(targetFilePath)) {
        emit appUpdateError(QStringLiteral("Update APK file not found on device. Please download again."));
        return;
    }

#ifdef Q_OS_ANDROID
    QJniObject jFilePath = QJniObject::fromString(targetFilePath);
    QJniObject::callStaticMethod<void>(
        "org/mavlink/qgroundcontrol/QGCActivity",
        "installApk",
        "(Ljava/lang/String;)V",
        jFilePath.object<jstring>()
    );
#endif
}

bool QGroundControlQmlGlobal::isUpdateDownloaded() const
{
    QString targetDir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation);
    if (targetDir.isEmpty()) {
        targetDir = QStandardPaths::writableLocation(QStandardPaths::TempLocation);
    }
    QString targetFilePath = QDir(targetDir).filePath(QStringLiteral("IRS_Alex_GCS_update.apk"));
    QFileInfo fi(targetFilePath);
    return fi.exists() && fi.size() > 10000000;
}


