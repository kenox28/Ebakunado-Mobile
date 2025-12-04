# Endpoint Usage Analysis: `get_immunization_schedule.php`

## Endpoint Definition
**Path:** `php/supabase/users/get_immunization_schedule.php`  
**Constant:** `AppConstants.immunizationScheduleEndpoint`  
**Location:** `lib/utils/constants.dart` (line 42-43)

---

## Files Using This Endpoint

### 1. **`lib/services/api_client.dart`** ✅ (API Service Layer)
**Line:** 198-204  
**Method:** `getImmunizationSchedule()`  
**Purpose:** API client method that makes the HTTP GET request to the endpoint

```dart
Future<Response> getImmunizationSchedule() async {
  await _ensureInitialized();
  final response = await _dio.get(AppConstants.immunizationScheduleEndpoint);
  return response;
}
```

**Role:** Service layer - handles the actual HTTP request

---

### 2. **`lib/screens/immunization_schedule_screen.dart`** ✅ (Primary Usage)
**Line:** 48  
**Method:** `_loadSchedule()`  
**Purpose:** Main screen for displaying immunization schedule with tabs (Schedule, Missed, Taken)

**Usage Details:**
- Calls `ApiClient.instance.getImmunizationSchedule()`
- Parses response into `ImmunizationScheduleResponse`
- Filters data by `babyId` to show schedule for specific child
- Displays in tabbed interface with counts

**Key Code:**
```dart
final response = await ApiClient.instance.getImmunizationSchedule();
final scheduleResponse = ImmunizationScheduleResponse.fromJson(responseData);
final childData = scheduleResponse.getForBaby(widget.babyId);
```

**Screen Purpose:** Dedicated screen for viewing immunization schedules

---

### 3. **`lib/screens/child_record_screen.dart`** ✅ (Secondary Usage)
**Line:** 99  
**Method:** `_loadVaccinationData()`  
**Purpose:** Loads vaccination history for display in child record

**Usage Details:**
- Calls `ApiClient.instance.getImmunizationSchedule()`
- Filters to get only TAKEN vaccinations for the specific child
- Displays in the vaccination ledger section of child record

**Key Code:**
```dart
final response = await ApiClient.instance.getImmunizationSchedule();
final scheduleResponse = ImmunizationScheduleResponse.fromJson(response.data);
_vaccinations = allVaccinations
    .where((v) => v.babyId == widget.babyId && (v.isTaken || v.status == 'taken'))
    .toList();
```

**Screen Purpose:** Shows complete child health record including vaccination history

---

## Related Files (Not Direct Usage)

### 4. **`lib/models/immunization.dart`** 📋 (Data Model)
**Purpose:** Defines the data models for parsing the endpoint response
- `ImmunizationItem` - Individual immunization record
- `ImmunizationScheduleResponse` - Response wrapper with helper methods
- Helper methods: `getForBaby()`, `getUpcomingForBaby()`, `getTakenForBaby()`, `getMissedForBaby()`

**Role:** Data model layer - structures the response data

---

### 5. **`lib/main.dart`** 📋 (Route Definition Only)
**Purpose:** Defines route for `ImmunizationScheduleScreen` (doesn't call endpoint directly)

**Role:** Navigation/routing - no direct endpoint usage

---

## Summary

### Direct API Calls: **2 Screens**
1. ✅ `immunization_schedule_screen.dart` - Primary usage (full schedule view)
2. ✅ `child_record_screen.dart` - Secondary usage (vaccination history only)

### Service Layer: **1 File**
1. ✅ `api_client.dart` - API method definition

### Supporting Files: **2 Files**
1. 📋 `models/immunization.dart` - Data models
2. 📋 `utils/constants.dart` - Endpoint constant definition
3. 📋 `main.dart` - Route definition (no direct usage)

---

## Usage Patterns

### Pattern 1: Full Schedule View (`immunization_schedule_screen.dart`)
- Loads all immunization data
- Filters by `babyId` client-side
- Shows upcoming, missed, and taken immunizations in tabs
- Displays counts in tab labels

### Pattern 2: Vaccination History (`child_record_screen.dart`)
- Loads all immunization data
- Filters to only TAKEN vaccinations
- Displays in vaccination ledger section
- Shows completed vaccinations only

---

## Recommendations

1. **Consider adding a `babyId` parameter** to the endpoint to reduce data transfer
   - Currently loads all immunizations and filters client-side
   - Could optimize by filtering server-side

2. **Consider caching** the response since it's used in multiple screens
   - Could implement a provider or cache mechanism

3. **Error handling** is consistent in both screens
   - Both handle DioException and auth errors properly

4. **Response parsing** is slightly different:
   - `immunization_schedule_screen.dart` handles both String and Map responses
   - `child_record_screen.dart` assumes Map response
   - Consider standardizing the parsing logic

---

## Endpoint Flow

```
User Action
    ↓
Screen calls ApiClient.getImmunizationSchedule()
    ↓
api_client.dart makes GET request to endpoint
    ↓
Response received
    ↓
Parsed into ImmunizationScheduleResponse
    ↓
Filtered by babyId (client-side)
    ↓
Displayed in UI
```

---

## Files Summary Table

| File | Type | Direct Usage | Purpose |
|------|------|--------------|---------|
| `api_client.dart` | Service | ✅ Yes | Makes HTTP request |
| `immunization_schedule_screen.dart` | Screen | ✅ Yes | Full schedule view |
| `child_record_screen.dart` | Screen | ✅ Yes | Vaccination history |
| `models/immunization.dart` | Model | ❌ No | Data structure |
| `utils/constants.dart` | Config | ❌ No | Endpoint definition |
| `main.dart` | Route | ❌ No | Navigation only |

