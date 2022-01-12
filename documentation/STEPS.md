# Test Steps

## Table of Contents

* [Introduction](#introduction)
* [Test Step Summary](#test-step-summary)
* [Details](#details)
  * [assert_connectivity](#assert_connectivity)
  * [reset_connectivity](#reset_connectivity)
  * [set_connectivity](#set_connectivity)


## Introduction

This plugin provides a few new [Test Steps](https://github.com/peiffer-innovations/automated_testing_framework/blob/main/documentation/STEPS.md) related to test connectivity related actions.


---

## Test Step Summary

Test Step IDs                               | Description
--------------------------------------------|-------------
[assert_connectivity](#assert_connectivity) | Asserts that the value of of the `connected` flag from the `ConnectivityPlugin` matches the value set in the step.
[reset_connectivity](#reset_connectivity)   | Clears any overrides from the `ConnectivityPlugin` and switches it back to live connectivity mode.
[set_connectivity](#set_connectivity)       | Sets the `connected` flag on the `ConnectivityPlugin` to simulate online / offline scenarios.


---
## Details


### assert_connectivity

**How it Works**

1. Checks to see if the `connected` flag from the `ConnectivityPlugin` matches the `connected` value.


**Example**

```json
{
  "id": "assert_connectivity",
  "image": "<optional_base_64_image>",
  "values": {
    "connected": true
  }
}
```

**Values**

Key         | Type    | Required | Supports Variable | Description
------------|---------|----------|-------------------|-------------
`connected` | boolean | Yes      | Yes               | The connected flag to expect the value on the `ConnectivityPlugin` to match.


---

### reset_connectivity

**How it Works**

1. Resets the `ConnectivityPlugin` back to the default state so that it gets the flags and values from the device.

**Example**

```json
{
  "id": "reset_connectivity",
  "image": "<optional_base_64_image>",
  "values": {}
}
```

**Values**

n/a


---

### set_connectivity

**How it Works**

1. Sets the `connected` override value on the `ConnectivityPlugin`.

**Example**

```json
{
  "id": "set_connectivity",
  "image": "<optional_base_64_image>",
  "values": {
    "connected": true
  }
}
```

**Values**

Key         | Type    | Required | Supports Variable | Description
------------|---------|----------|-------------------|-------------
`connected` | boolean | Yes      | Yes               | The true / false value to set as the override.


