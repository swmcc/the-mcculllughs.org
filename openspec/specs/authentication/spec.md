# Authentication Domain Specification

## Overview

The authentication domain handles user registration, login, password management, and role-based access control using Devise.

## Requirements

### REQ-AUTH-001: User Registration

The system MUST allow new users to register with the following fields:
- Email (required, unique)
- Password (required, minimum 6 characters)
- Name (required)

The system MUST assign the `member` role by default to new users.

### REQ-AUTH-002: User Authentication

The system MUST require authentication for all routes except:
- Login page
- Registration page
- Password reset pages

The system MUST use Devise for authentication with the following modules:
- `database_authenticatable`
- `registerable`
- `recoverable`
- `rememberable`
- `validatable`

### REQ-AUTH-003: Role-Based Access Control

The system MUST support two user roles:
- `member` (default, value: 0)
- `admin` (value: 1)

The system MUST restrict admin features to users with the `admin` role.

### REQ-AUTH-004: Session Management

The system MUST support "remember me" functionality via Devise's `rememberable` module.

The system MUST allow users to sign out, which SHALL destroy their session.

### REQ-AUTH-005: Password Recovery

The system MUST allow users to request a password reset via email.

The system MUST generate a unique reset token that expires.

## Scenarios

### SCENARIO: User Registration

**Given** a visitor on the registration page
**When** they submit valid registration data (email, password, name)
**Then** a new user account SHALL be created
**And** the user SHALL be assigned the `member` role
**And** the user SHALL be automatically signed in
**And** the user SHALL be redirected to the galleries index

### SCENARIO: User Login

**Given** a registered user on the login page
**When** they submit valid credentials
**Then** the user SHALL be authenticated
**And** a session SHALL be created
**And** the user SHALL be redirected to the galleries index

### SCENARIO: Invalid Login

**Given** a visitor on the login page
**When** they submit invalid credentials
**Then** authentication SHALL fail
**And** an error message SHALL be displayed
**And** the user SHALL remain on the login page

### SCENARIO: Unauthenticated Access

**Given** a visitor not signed in
**When** they attempt to access a protected route
**Then** they SHALL be redirected to the login page
**And** a message SHALL indicate authentication is required

### SCENARIO: Admin Access Control

**Given** a user with the `member` role
**When** they attempt to access an admin-only feature
**Then** access SHALL be denied
**And** the user SHALL be redirected to the root path
**And** an "Access denied" message SHALL be displayed

### SCENARIO: Password Reset Request

**Given** a user who has forgotten their password
**When** they request a password reset with their email
**Then** a reset email SHALL be sent
**And** the email SHALL contain a unique reset link

### SCENARIO: Password Reset Completion

**Given** a user with a valid password reset token
**When** they submit a new password
**Then** their password SHALL be updated
**And** they SHALL be signed in automatically
**And** they SHALL be redirected to the galleries index

### SCENARIO: Sign Out

**Given** an authenticated user
**When** they sign out
**Then** their session SHALL be destroyed
**And** they SHALL be redirected to the login page
