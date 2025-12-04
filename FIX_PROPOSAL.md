# Fix Proposal: MUAC/Next Schedule Display & Button Responsiveness

## Issue 1: MUAC and Next Schedule Not Displaying

### Problem Analysis
The code looks correct, but the data might not be coming from the API. Let me check:

**Possible Causes:**
1. PHP endpoint might not be sending `next_schedule_date` field yet (it was mentioned in proposal but not in actual PHP code)
2. The field name in PHP might be different (e.g., `next_schedule_date` vs `nextScheduleDate`)
3. Data might be null/empty in database

**Current Code Status:**
- ✅ Model has `nextScheduleDate` field
- ✅ Model parses `json['next_schedule_date']`
- ✅ Table displays `nextScheduleFormatted`
- ✅ MUAC formatting function exists

### Solution
1. **Add debug logging** to see what data is actually received
2. **Check PHP endpoint** - ensure it's sending `next_schedule_date` field
3. **Handle alternative field names** if PHP uses different naming

---

## Issue 2: Button Text Not Responsive (Wrapping)

### Current Problem
Buttons use `Text` widget with `textAlign: TextAlign.center` but text doesn't wrap when it's too long. On small screens, text gets cut off or overflowed.

### Current Button Structure:
```dart
label: Text(
  'Request Baby Card',
  textAlign: TextAlign.center,
),
```

### Proposed Solution

**Option A: Use Text with maxLines and overflow**
```dart
label: Text(
  'Request\nBaby Card',  // Manual line break
  textAlign: TextAlign.center,
  maxLines: 2,
  overflow: TextOverflow.ellipsis,
),
```

**Option B: Use Flexible/Expanded with Column layout** (Better)
```dart
label: Flexible(
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('Request', textAlign: TextAlign.center),
      Text('Baby Card', textAlign: TextAlign.center),
    ],
  ),
),
```

**Option C: Use RichText with automatic wrapping** (Best)
```dart
label: Flexible(
  child: Text(
    'Request Baby Card',
    textAlign: TextAlign.center,
    maxLines: 2,
    overflow: TextOverflow.visible,
    softWrap: true,
  ),
),
```

**Option D: Use SizedBox with FittedBox** (Most Responsive)
```dart
label: SizedBox(
  width: double.infinity,
  child: FittedBox(
    fit: BoxFit.scaleDown,
    child: Text(
      'Request Baby Card',
      textAlign: TextAlign.center,
      maxLines: 2,
    ),
  ),
),
```

### Recommended Solution: **Option D with maxLines**
- Automatically scales text down if needed
- Allows text to wrap to 2 lines
- Maintains center alignment
- Works on all screen sizes

---

## Implementation Plan

### Step 1: Fix MUAC/Next Schedule Display
1. Add debug print to see actual API response
2. Verify field names match between PHP and Dart
3. Add fallback handling for missing data

### Step 2: Fix Button Responsiveness
1. Wrap button labels in SizedBox with FittedBox
2. Set maxLines: 2 for text wrapping
3. Test on different screen sizes

---

## Visual Comparison

### Before (Current):
```
┌──────────────┐ ┌──────────────┐
│[📚 Request   │ │[🔄 Request   │
│ Baby Card]   │ │ Transfer]    │  ← Text might overflow on small screens
└──────────────┘ └──────────────┘
```

### After (Proposed):
```
┌──────────────┐ ┌──────────────┐
│[📚 Request   │ │[🔄 Request   │
│   Baby       │ │  Transfer    │  ← Text wraps to 2 lines automatically
│   Card]      │ │              │
└──────────────┘ └──────────────┘
```

Or on very small screens:
```
┌──────────┐ ┌──────────┐
│[📚      │ │[🔄      │
│ Request │ │ Request │  ← Text scales down and wraps
│  Baby   │ │Transfer │
│  Card]  │ │         │
└──────────┘ └──────────┘
```

