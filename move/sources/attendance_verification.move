module eia::attendance_verification;

use std::string::{Self, String};
use sui::clock::{Self, Clock};
use sui::table::{Self, Table};
use sui::event;
use eia::event_management::{Self, Event};
use eia::identity_access::{Self, RegistrationRegistry};

// Error codes
const EEventNotActive: u64 = 1;
const EAlreadyCheckedIn: u64 = 3;
const ENotCheckedIn: u64 = 4;
const EInvalidPass: u64 = 5;
const ECheckOutBeforeCheckIn: u64 = 7;

// Attendance states
const STATE_REGISTERED: u8 = 0;
const STATE_CHECKED_IN: u8 = 1;
const STATE_CHECKED_OUT: u8 = 2;

// Attendance tracking
public struct AttendanceRegistry has key {
    id: UID,
    // event_id -> attendances
    event_attendances: Table<ID, EventAttendance>,
    // wallet -> attendance records
    user_attendances: Table<address, vector<AttendanceRecord>>,
}

public struct EventAttendance has store {
    records: Table<address, AttendanceRecord>,
    check_in_count: u64,
    check_out_count: u64,
    unique_devices: Table<vector<u8>, bool>, // Device fingerprint tracking
}

public struct AttendanceRecord has store, drop, copy {
    event_id: ID,
    wallet: address,
    state: u8,
    check_in_time: u64,
    check_out_time: u64,
    device_fingerprint: vector<u8>,
    location_proof: vector<u8>, // Encrypted location data
}

// NFT trigger capability (sent to NFT contract)
public struct MintPoACapability has key, store {
    id: UID, 
    event_id: ID,
    wallet: address,
    check_in_time: u64,
}

public struct MintCompletionCapability has key, store {
    id: UID, 
    event_id: ID,
    wallet: address,
    check_in_time: u64,
    check_out_time: u64,
    attendance_duration: u64,
}

// Events emitted
public struct AttendeeCheckedIn has copy, drop {
    event_id: ID,
    wallet: address,
    check_in_time: u64,
}

public struct AttendeeCheckedOut has copy, drop {
    event_id: ID,
    wallet: address,
    check_out_time: u64,
    attendance_duration: u64,
}

public struct FraudAttemptDetected has copy, drop {
    event_id: ID,
    wallet: address,
    reason: String,
    timestamp: u64,
}

// Initialize the module
fun init(ctx: &mut TxContext) {
    let registry = AttendanceRegistry {
        id: object::new(ctx),
        event_attendances: table::new(ctx),
        user_attendances: table::new(ctx),
    };
    transfer::share_object(registry);
}

// Process check-in
public fun check_in(
    pass_hash: vector<u8>,
    device_fingerprint: vector<u8>,
    location_proof: vector<u8>,
    event: &mut Event,
    attendance_registry: &mut AttendanceRegistry,
    identity_registry: &mut RegistrationRegistry,
    clock: &Clock,
    ctx: &mut TxContext
): MintPoACapability {
    let event_id = event_management::get_event_id(event);
    
    // Verify event is active
    assert!(event_management::is_event_active(event), EEventNotActive);
    
    // Validate pass and get wallet
    let (valid, wallet) = identity_access::validate_pass(
        pass_hash,
        event_id,
        identity_registry,
        clock
    );
    assert!(valid, EInvalidPass);
    
    // Initialize event attendance if needed
    if (!table::contains(&attendance_registry.event_attendances, event_id)) {
        let event_attendance = EventAttendance {
            records: table::new(ctx),
            check_in_count: 0,
            check_out_count: 0,
            unique_devices: table::new(ctx),
        };
        table::add(&mut attendance_registry.event_attendances, event_id, event_attendance);
    };

    let event_attendance = table::borrow_mut(&mut attendance_registry.event_attendances, event_id);
    
    // Check for duplicate check-in
    if (table::contains(&event_attendance.records, wallet)) {
        let record = table::borrow(&event_attendance.records, wallet);
        assert!(record.state != STATE_CHECKED_IN, EAlreadyCheckedIn);
    };

    // Fraud detection - check device fingerprint
    if (vector::length(&device_fingerprint) > 0) {
        if (table::contains(&event_attendance.unique_devices, device_fingerprint)) {
            event::emit(FraudAttemptDetected {
                event_id,
                wallet,
                reason: string::utf8(b"Duplicate device fingerprint"),
                timestamp: clock::timestamp_ms(clock),
            });
        } else {
            table::add(&mut event_attendance.unique_devices, device_fingerprint, true);
        };
    };

    let check_in_time = clock::timestamp_ms(clock);
    
    // Create attendance record
    let record = AttendanceRecord {
        event_id,
        wallet,
        state: STATE_CHECKED_IN,
        check_in_time,
        check_out_time: 0,
        device_fingerprint,
        location_proof,
    };

    // Store attendance record
    if (table::contains(&event_attendance.records, wallet)) {
        *table::borrow_mut(&mut event_attendance.records, wallet) = record;
    } else {
        table::add(&mut event_attendance.records, wallet, record);
    };

    event_attendance.check_in_count = event_attendance.check_in_count + 1;

    // Update user's attendance history
    if (!table::contains(&attendance_registry.user_attendances, wallet)) {
        table::add(&mut attendance_registry.user_attendances, wallet, vector::empty());
    };
    let user_records = table::borrow_mut(&mut attendance_registry.user_attendances, wallet);
    vector::push_back(user_records, record);

    // Update event attendee count
    event_management::increment_attendees(event);

    // Mark as checked in identity registry
    identity_access::mark_checked_in(wallet, event_id, identity_registry);

    event::emit(AttendeeCheckedIn {
        event_id,
        wallet,
        check_in_time,
    });

    // Return capability for NFT minting
    MintPoACapability {
        id: object::new(ctx),
        event_id,
        wallet,
        check_in_time,
    }
}

// Process check-out
public fun check_out(
    wallet: address,
    event_id: ID,
    attendance_registry: &mut AttendanceRegistry,
    clock: &Clock,
    ctx: &mut TxContext
): MintCompletionCapability {
    // Check if event has any attendance records FIRST
    assert!(table::contains(&attendance_registry.event_attendances, event_id), ENotCheckedIn);
    
    let event_attendance = table::borrow_mut(&mut attendance_registry.event_attendances, event_id);
    
    // Verify user is checked in
    assert!(table::contains(&event_attendance.records, wallet), ENotCheckedIn);
    let record = table::borrow_mut(&mut event_attendance.records, wallet);
    assert!(record.state == STATE_CHECKED_IN, ECheckOutBeforeCheckIn);

    let check_out_time = clock::timestamp_ms(clock);
    let attendance_duration = check_out_time - record.check_in_time;

    // Update record
    record.state = STATE_CHECKED_OUT;
    record.check_out_time = check_out_time;

    event_attendance.check_out_count = event_attendance.check_out_count + 1;

    // Update user's history
    let user_records = table::borrow_mut(&mut attendance_registry.user_attendances, wallet);
    let mut i = 0;
    let len = vector::length(user_records);
    while (i < len) {
        let user_record = vector::borrow_mut(user_records, i);
        if (user_record.event_id == event_id && user_record.state == STATE_CHECKED_IN) {
            user_record.state = STATE_CHECKED_OUT;
            user_record.check_out_time = check_out_time;
            break
        };
        i = i + 1;
    };

    event::emit(AttendeeCheckedOut {
        event_id,
        wallet,
        check_out_time,
        attendance_duration,
    });

    // Return capability for completion NFT minting
    MintCompletionCapability {
        id: object::new(ctx),
        event_id,
        wallet,
        check_in_time: record.check_in_time,
        check_out_time,
        attendance_duration,
    }
}

// Check attendance status
public fun get_attendance_status(
    wallet: address,
    event_id: ID,
    attendance_registry: &AttendanceRegistry,
): (bool, u8, u64, u64) {
    if (!table::contains(&attendance_registry.event_attendances, event_id)) {
        return (false, STATE_REGISTERED, 0, 0)
    };

    let event_attendance = table::borrow(&attendance_registry.event_attendances, event_id);
    
    if (!table::contains(&event_attendance.records, wallet)) {
        return (false, STATE_REGISTERED, 0, 0)
    };

    let record = table::borrow(&event_attendance.records, wallet);
    (true, record.state, record.check_in_time, record.check_out_time)
}

// Get event statistics
public fun get_event_stats(
    event_id: ID,
    attendance_registry: &AttendanceRegistry,
): (u64, u64, u64) {
    if (!table::contains(&attendance_registry.event_attendances, event_id)) {
        return (0, 0, 0)
    };

    let event_attendance = table::borrow(&attendance_registry.event_attendances, event_id);
    let completion_rate = if (event_attendance.check_in_count > 0) {
        (event_attendance.check_out_count * 10000) / event_attendance.check_in_count
    } else {
        0
    };

    (event_attendance.check_in_count, event_attendance.check_out_count, completion_rate)
}

// Get user's attendance history
public fun get_user_attendance_history(
    wallet: address,
    attendance_registry: &AttendanceRegistry,
): vector<AttendanceRecord> {
    if (!table::contains(&attendance_registry.user_attendances, wallet)) {
        return vector::empty()
    };

    *table::borrow(&attendance_registry.user_attendances, wallet)
}

// Verify attendance completion for rating eligibility
public fun verify_attendance_completion(
    wallet: address,
    event_id: ID,
    attendance_registry: &AttendanceRegistry,
): bool {
    if (!table::contains(&attendance_registry.event_attendances, event_id)) {
        return false
    };

    let event_attendance = table::borrow(&attendance_registry.event_attendances, event_id);
    
    if (!table::contains(&event_attendance.records, wallet)) {
        return false
    };

    let record = table::borrow(&event_attendance.records, wallet);
    record.state == STATE_CHECKED_OUT
}

// Getters for capability data
public fun get_poa_capability_data(cap: &MintPoACapability): (ID, address, u64) {
    (cap.event_id, cap.wallet, cap.check_in_time)
}

public fun get_completion_capability_data(cap: &MintCompletionCapability): (ID, address, u64, u64, u64) {
    (cap.event_id, cap.wallet, cap.check_in_time, cap.check_out_time, cap.attendance_duration)
}

// Consume capabilities (called by NFT contract)
public fun consume_poa_capability(cap: MintPoACapability): (ID, address, u64) {
    let MintPoACapability {id, event_id, wallet, check_in_time } = cap;
    object::delete(id);
    (event_id, wallet, check_in_time)
}

public fun consume_completion_capability(cap: MintCompletionCapability): (ID, address, u64, u64, u64) {
    let MintCompletionCapability {id, event_id, wallet, check_in_time, check_out_time, attendance_duration } = cap;
    object::delete(id);
    (event_id, wallet, check_in_time, check_out_time, attendance_duration)
}

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}

#[test_only]
public fun create_mock_poa_capability_for_testing(
    event_id: ID,
    wallet: address,
    check_in_time: u64,
    ctx: &mut TxContext
): MintPoACapability {
    MintPoACapability {
        id: object::new(ctx),
        event_id,
        wallet,
        check_in_time,
    }
}

#[test_only]
public fun create_mock_completion_capability_for_testing(
    event_id: ID,
    wallet: address,
    check_in_time: u64,
    check_out_time: u64,
    attendance_duration: u64,
    ctx: &mut TxContext
): MintCompletionCapability {
    MintCompletionCapability {
        id: object::new(ctx),
        event_id,
        wallet,
        check_in_time,
        check_out_time,
        attendance_duration,
    }
}

#[test_only]
public fun simulate_checkin_for_testing(
    wallet: address,
    event_id: ID,
    attendance_registry: &mut AttendanceRegistry,
    clock: &Clock,
    ctx: &mut TxContext
) {
    let current_time = clock::timestamp_ms(clock);
    
    // Initialize event attendance if needed
    if (!table::contains(&attendance_registry.event_attendances, event_id)) {
        let event_attendance = EventAttendance {
            records: table::new(ctx),
            check_in_count: 0,
            check_out_count: 0,
            unique_devices: table::new(ctx),
        };
        table::add(&mut attendance_registry.event_attendances, event_id, event_attendance);
    };

    let event_attendance = table::borrow_mut(&mut attendance_registry.event_attendances, event_id);
    
    // Create attendance record
    let record = AttendanceRecord {
        event_id,
        wallet,
        state: STATE_CHECKED_IN,
        check_in_time: current_time,
        check_out_time: 0,
        device_fingerprint: b"test_device",
        location_proof: b"test_location",
    };
    
    // Add or update record
    if (table::contains(&event_attendance.records, wallet)) {
        let existing_record = table::borrow_mut(&mut event_attendance.records, wallet);
        existing_record.state = STATE_CHECKED_IN;
        existing_record.check_in_time = current_time;
    } else {
        table::add(&mut event_attendance.records, wallet, record);
        event_attendance.check_in_count = event_attendance.check_in_count + 1;
    };
    
    // Update user attendances
    if (!table::contains(&attendance_registry.user_attendances, wallet)) {
        table::add(&mut attendance_registry.user_attendances, wallet, vector::empty());
    };
    let user_records = table::borrow_mut(&mut attendance_registry.user_attendances, wallet);
    vector::push_back(user_records, record);
}

#[test_only]
public fun simulate_checkout_for_testing(
    wallet: address,
    event_id: ID,
    attendance_registry: &mut AttendanceRegistry,
    clock: &Clock,
    _ctx: &mut TxContext
) {
    let current_time = clock::timestamp_ms(clock);
    
    // Get event attendance
    let event_attendance = table::borrow_mut(&mut attendance_registry.event_attendances, event_id);
    
    // Update existing record
    if (table::contains(&event_attendance.records, wallet)) {
        let record = table::borrow_mut(&mut event_attendance.records, wallet);
        if (record.state == STATE_CHECKED_IN) {
            record.state = STATE_CHECKED_OUT;
            record.check_out_time = current_time;
            event_attendance.check_out_count = event_attendance.check_out_count + 1;
        };
    };
}