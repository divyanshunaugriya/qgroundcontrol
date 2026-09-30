#include "BatteryFactGroupListModel.h"
#include "Vehicle.h"
#include "MAVLinkLib.h"

BatteryFactGroupListModel::BatteryFactGroupListModel(QObject* parent)
    : FactGroupListModel("battery", parent)
{

}

bool BatteryFactGroupListModel::_shouldHandleMessage(const mavlink_message_t &message, QList<uint32_t> &ids) const
{
    ids.clear();

    switch (message.msgid) {
    case MAVLINK_MSG_ID_HIGH_LATENCY:
    case MAVLINK_MSG_ID_HIGH_LATENCY2:
        ids.append(0); // High latency messages do not have a battery id
        return true;
    case MAVLINK_MSG_ID_BATTERY_STATUS:
    {
        mavlink_battery_status_t batteryStatus{};
        mavlink_msg_battery_status_decode(&message, &batteryStatus);
        ids.append(batteryStatus.id);
        return true;
    }
    case MAVLINK_MSG_ID_SYS_STATUS:
    {
        mavlink_sys_status_t sysStatus{};
        mavlink_msg_sys_status_decode(&message, &sysStatus);
        if (sysStatus.voltage_battery != UINT16_MAX && sysStatus.voltage_battery > 0) {
            ids.append(0);
            return true;
        }
        return false;
    }
    default:
        return false; // Not a message we care about
    }
}

FactGroupWithId *BatteryFactGroupListModel::_createFactGroupWithId(uint32_t id)
{
    return new BatteryFactGroup(id, this);
}

BatteryFactGroup::BatteryFactGroup(uint32_t batteryId, QObject *parent)
    : FactGroupWithId(1000, QStringLiteral(":/json/Vehicle/BatteryFact.json"), parent)
{
    _addFact(&_batteryFunctionFact);
    _addFact(&_batteryTypeFact);
    _addFact(&_voltageFact);
    _addFact(&_currentFact);
    _addFact(&_mahConsumedFact);
    _addFact(&_temperatureFact);
    _addFact(&_percentRemainingFact);
    _addFact(&_timeRemainingFact);
    _addFact(&_timeRemainingStrFact);
    _addFact(&_chargeStateFact);
    _addFact(&_instantPowerFact);

    _idFact.setRawValue(batteryId);
    _batteryFunctionFact.setRawValue(MAV_BATTERY_FUNCTION_UNKNOWN);
    _batteryTypeFact.setRawValue(MAV_BATTERY_TYPE_UNKNOWN);
    _voltageFact.setRawValue(qQNaN());
    _currentFact.setRawValue(qQNaN());
    _mahConsumedFact.setRawValue(qQNaN());
    _temperatureFact.setRawValue(qQNaN());
    _percentRemainingFact.setRawValue(qQNaN());
    _timeRemainingFact.setRawValue(qQNaN());
    _chargeStateFact.setRawValue(MAV_BATTERY_CHARGE_STATE_UNDEFINED);
    _instantPowerFact.setRawValue(qQNaN());

    (void) connect(&_timeRemainingFact, &Fact::rawValueChanged, this, &BatteryFactGroup::_timeRemainingChanged);
}

void BatteryFactGroup::handleMessage(Vehicle *vehicle, const mavlink_message_t &message)
{
    switch (message.msgid) {
    case MAVLINK_MSG_ID_HIGH_LATENCY:
        _handleHighLatency(vehicle, message);
        break;
    case MAVLINK_MSG_ID_HIGH_LATENCY2:
        _handleHighLatency2(vehicle, message);
        break;
    case MAVLINK_MSG_ID_BATTERY_STATUS:
        _handleBatteryStatus(vehicle, message);
        break;
    case MAVLINK_MSG_ID_SYS_STATUS:
        _handleSysStatus(vehicle, message);
        break;
    default:
        break;
    }
}

int BatteryFactGroup::detectLipoCellCount(double voltage)
{
    if (voltage <= 0.0) {
        return 1;
    }
    const int candidates[] = { 1, 2, 3, 4, 5, 6, 7, 8, 10, 12, 14, 16 };

    for (int cells : candidates) {
        double vCell = voltage / static_cast<double>(cells);
        if (vCell >= 3.00 && vCell <= 4.35) {
            return cells;
        }
    }

    for (int cells : candidates) {
        double vCell = voltage / static_cast<double>(cells);
        if (vCell >= 2.70 && vCell <= 4.45) {
            return cells;
        }
    }

    int cells = qRound(voltage / 3.7);
    return qMax(1, cells);
}

double BatteryFactGroup::calculateBatteryPercent(double totalVoltage, bool isArmed, double mahConsumed)
{
    // If mAh consumed is actively tracking an 11,000 mAh pack, prioritize smooth Coulomb counting
    constexpr double totalCapacityMah = 11000.0;
    if (!qIsNaN(mahConsumed) && mahConsumed > 50.0 && mahConsumed <= totalCapacityMah * 1.2) {
        double pctMah = (1.0 - (mahConsumed / totalCapacityMah)) * 100.0;
        pctMah = qBound(0.0, pctMah, 100.0);
        if (totalVoltage <= 12.1 && pctMah > 5.0) {
            return 5.0;
        }
        return pctMah;
    }

    int cells = detectLipoCellCount(totalVoltage);
    double vCell = totalVoltage / static_cast<double>(cells);

    struct LutEntry {
        double voltage;
        double percent;
    };

    // Li-ion 4S flight load curve: accounts for 1.0V-1.2V takeoff sag. Full ~15.6V (3.90V/cell), 0% cutoff at 12.0V (3.00V/cell)
    static const LutEntry armedLut[] = {
        { 3.900, 100.0 },
        { 3.800,  90.0 },
        { 3.700,  80.0 },
        { 3.600,  70.0 },
        { 3.525,  60.0 },
        { 3.450,  50.0 },
        { 3.375,  40.0 },
        { 3.300,  30.0 },
        { 3.200,  20.0 },
        { 3.100,  10.0 },
        { 3.000,   0.0 }
    };

    // Li-ion resting curve when disarmed on ground: full at 16.6V-16.8V (4.15V/cell), cutoff at 12.5V (3.125V/cell)
    static const LutEntry disarmedLut[] = {
        { 4.150, 100.0 },
        { 4.050,  90.0 },
        { 3.950,  80.0 },
        { 3.850,  70.0 },
        { 3.750,  60.0 },
        { 3.650,  50.0 },
        { 3.550,  40.0 },
        { 3.450,  30.0 },
        { 3.350,  20.0 },
        { 3.250,  10.0 },
        { 3.125,   0.0 }
    };

    const LutEntry *lut = isArmed ? armedLut : disarmedLut;
    const int lutSize = isArmed ? static_cast<int>(sizeof(armedLut) / sizeof(armedLut[0])) : static_cast<int>(sizeof(disarmedLut) / sizeof(disarmedLut[0]));

    if (vCell >= lut[0].voltage) {
        return 100.0;
    }
    if (vCell <= lut[lutSize - 1].voltage) {
        return 0.0;
    }

    for (int i = 0; i < lutSize - 1; ++i) {
        if (vCell >= lut[i + 1].voltage) {
            double vHigh = lut[i].voltage;
            double vLow  = lut[i + 1].voltage;
            double pHigh = lut[i].percent;
            double pLow  = lut[i + 1].percent;
            double fraction = (vCell - vLow) / (vHigh - vLow);
            return qBound(0.0, pLow + fraction * (pHigh - pLow), 100.0);
        }
    }
    return 0.0;
}

double BatteryFactGroup::calculateLipoPercent(double totalVoltage)
{
    return calculateBatteryPercent(totalVoltage, false, -1.0);
}

double BatteryFactGroup::calculateLipoPercentFromCellVoltage(double vCell)
{
    return calculateBatteryPercent(vCell * 4.0, false, -1.0);
}

void BatteryFactGroup::_handleHighLatency(Vehicle * /*vehicle*/, const mavlink_message_t &message)
{
    mavlink_high_latency_t highLatency{};
    mavlink_msg_high_latency_decode(&message, &highLatency);

    percentRemaining()->setRawValue((highLatency.battery_remaining == UINT8_MAX) ? qQNaN() : highLatency.battery_remaining);

    _setTelemetryAvailable(true);
}

void BatteryFactGroup::_handleHighLatency2(Vehicle * /*vehicle*/, const mavlink_message_t &message)
{
    mavlink_high_latency2_t highLatency2{};
    mavlink_msg_high_latency2_decode(&message, &highLatency2);

    percentRemaining()->setRawValue((highLatency2.battery == -1) ? qQNaN() : highLatency2.battery);

    _setTelemetryAvailable(true);
}

void BatteryFactGroup::_handleBatteryStatus(Vehicle *vehicle, const mavlink_message_t &message)
{
    mavlink_battery_status_t batteryStatus{};
    mavlink_msg_battery_status_decode(&message, &batteryStatus);

    if (batteryStatus.id != id()->rawValue().toUInt()) {
        // Disregard battery status messages which are not targeted at this battery id
        return;
    }

    double totalVoltage = qQNaN();
    for (int i = 0; i < 10; i++) {
        const double cellVoltage = ((batteryStatus.voltages[i] == UINT16_MAX)) ? qQNaN() : (static_cast<double>(batteryStatus.voltages[i]) / 1000.0);
        if (qIsNaN(cellVoltage)) {
            break;
        }
        if (i == 0) {
            totalVoltage = cellVoltage;
        } else {
            totalVoltage += cellVoltage;
        }
    }

    for (int i = 0; i < 4; i++) {
        const double cellVoltage = ((batteryStatus.voltages_ext[i] == 0)) ? qQNaN() : (static_cast<double>(batteryStatus.voltages_ext[i]) / 1000.0);
        if (qIsNaN(cellVoltage)) {
            break;
        }
        totalVoltage += cellVoltage;
    }

    function()->setRawValue(batteryStatus.battery_function);
    type()->setRawValue(batteryStatus.type);
    temperature()->setRawValue((batteryStatus.temperature == INT16_MAX) ? qQNaN() : (static_cast<double>(batteryStatus.temperature) / 100.0));
    voltage()->setRawValue(totalVoltage);
    current()->setRawValue((batteryStatus.current_battery == -1) ? qQNaN() : (static_cast<double>(batteryStatus.current_battery) / 100.0));
    mahConsumed()->setRawValue((batteryStatus.current_consumed == -1) ? qQNaN() : batteryStatus.current_consumed);

    const bool isArmed = vehicle ? vehicle->armed() : false;
    const double mah = mahConsumed()->rawValue().toDouble();

    double pct = (batteryStatus.battery_remaining == -1) ? qQNaN() : static_cast<double>(batteryStatus.battery_remaining);
    if (qIsNaN(pct) && !qIsNaN(totalVoltage) && totalVoltage > 2.8) {
        pct = calculateBatteryPercent(totalVoltage, isArmed, mah);
    }
    percentRemaining()->setRawValue(pct);
    timeRemaining()->setRawValue((batteryStatus.time_remaining == 0) ? qQNaN() : batteryStatus.time_remaining);

    uint8_t cState = batteryStatus.charge_state;
    if (cState == MAV_BATTERY_CHARGE_STATE_UNDEFINED && !qIsNaN(pct)) {
        if (pct > 20.0) {
            cState = MAV_BATTERY_CHARGE_STATE_OK;
        } else if (pct > 10.0) {
            cState = MAV_BATTERY_CHARGE_STATE_LOW;
        } else {
            cState = MAV_BATTERY_CHARGE_STATE_CRITICAL;
        }
    }
    chargeState()->setRawValue(cState);
    instantPower()->setRawValue(totalVoltage * current()->rawValue().toDouble());

    _setTelemetryAvailable(true);
}

void BatteryFactGroup::_handleSysStatus(Vehicle *vehicle, const mavlink_message_t &message)
{
    if (id()->rawValue().toUInt() != 0) {
        return;
    }

    mavlink_sys_status_t sysStatus{};
    mavlink_msg_sys_status_decode(&message, &sysStatus);

    if (sysStatus.voltage_battery != UINT16_MAX && sysStatus.voltage_battery > 0) {
        const double v = static_cast<double>(sysStatus.voltage_battery) / 1000.0;
        voltage()->setRawValue(v);

        const bool isArmed = vehicle ? vehicle->armed() : false;
        double pct = (sysStatus.battery_remaining == -1) ? qQNaN() : static_cast<double>(sysStatus.battery_remaining);
        if (qIsNaN(pct) && v > 2.8) {
            pct = calculateBatteryPercent(v, isArmed);
        }
        percentRemaining()->setRawValue(pct);

        if (chargeState()->rawValue().toUInt() == MAV_BATTERY_CHARGE_STATE_UNDEFINED && !qIsNaN(pct)) {
            if (pct > 20.0) {
                chargeState()->setRawValue(MAV_BATTERY_CHARGE_STATE_OK);
            } else if (pct > 10.0) {
                chargeState()->setRawValue(MAV_BATTERY_CHARGE_STATE_LOW);
            } else {
                chargeState()->setRawValue(MAV_BATTERY_CHARGE_STATE_CRITICAL);
            }
        }
    }

    if (sysStatus.current_battery != -1) {
        const double curr = static_cast<double>(sysStatus.current_battery) / 100.0;
        current()->setRawValue(curr);
        if (!qIsNaN(voltage()->rawValue().toDouble())) {
            instantPower()->setRawValue(voltage()->rawValue().toDouble() * curr);
        }
    }

    _setTelemetryAvailable(true);
}

void BatteryFactGroup::_timeRemainingChanged(const QVariant &value)
{
    if (qIsNaN(value.toDouble())) {
        _timeRemainingStrFact.setRawValue("––:––:––");
    } else {
        const int totalSeconds = value.toInt();
        const int hours = totalSeconds / 3600;
        const int minutes = (totalSeconds % 3600) / 60;
        const int seconds = totalSeconds % 60;

        _timeRemainingStrFact.setRawValue(QString::asprintf("%02dH:%02dM:%02dS", hours, minutes, seconds));
    }
}
