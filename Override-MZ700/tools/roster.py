"""OVERRIDE droid roster (original designs, shared with the VZ300 version).
The first digit of a droid's number is its class."""

W_NONE, W_ZAP, W_LASER, W_TWIN, W_RAPID, W_CANNON = range(6)
WEAPON_NAMES = ['NONE', 'ARC ZAPPER', 'LASER', 'TWIN LASER', 'PULSE GUN', 'PLASMA CANNON']
# weapon: (damage, reload frames @25fps, shot range in cells)
WEAPONS = {
    W_NONE: (0, 0, 0),
    W_ZAP: (4, 14, 7),
    W_LASER: (6, 12, 14),
    W_TWIN: (6, 9, 14),
    W_RAPID: (4, 5, 12),
    W_CANNON: (14, 16, 16),
}

# number, name, energy, speed (1/16 cell per frame), weapon, aggression 0-3, blurb (2 lines)
ROSTER = [
    (0, 'LINK PROBE', 40, 9, W_NONE, 0, 'PROTOTYPE LINK UNIT. UNARMED.', 'IT CAN SEIZE ANY DROID IT TOUCHES.'),
    (104, 'DUSTER', 20, 4, W_NONE, 0, 'DECK SWEEPER. SLOW AND HARMLESS.', 'EASY TO SEIZE.'),
    (152, 'COURIER', 22, 8, W_NONE, 0, 'MESSAGE RUNNER.', 'QUICK ON ITS WHEELS.'),
    (218, 'STEWARD', 28, 6, W_ZAP, 1, 'CABIN SERVICE UNIT', 'WITH A STUN ARC.'),
    (263, 'WELDER', 34, 5, W_ZAP, 1, 'REPAIR DROID. ITS TORCH', 'MAKES A FAIR WEAPON.'),
    (307, 'PORTER', 52, 4, W_NONE, 1, 'CARGO HAULER.', 'HEAVY PLATING, NO GUNS.'),
    (355, 'TECHNICIAN', 36, 6, W_LASER, 1, 'SYSTEMS TECH WITH', 'A CUTTING LASER.'),
    (408, 'MEDIC', 40, 6, W_ZAP, 1, 'SICKBAY UNIT.', 'TOUGHER THAN IT LOOKS.'),
    (461, 'SENTRY', 46, 6, W_LASER, 2, 'SECURITY POST DROID.', 'SHOOTS ON SIGHT.'),
    (524, 'SURVEYOR', 44, 9, W_LASER, 2, 'SCOUT FRAME.', 'FAST AND ALERT.'),
    (587, 'WARDEN', 56, 6, W_TWIN, 2, 'BRIG GUARD WITH', 'TWIN LASERS.'),
    (632, 'ENFORCER', 64, 7, W_TWIN, 3, 'RIOT UNIT.', 'ARMOURED AND ANGRY.'),
    (668, 'BULWARK', 90, 4, W_LASER, 2, 'WALKING BLAST SHIELD.', 'HARD TO STOP.'),
    (705, 'TROOPER', 70, 8, W_RAPID, 3, 'BATTLE DROID', 'WITH A PULSE GUN.'),
    (773, 'HUNTER', 66, 10, W_RAPID, 3, 'PURSUIT FRAME.', 'FAST AND RELENTLESS.'),
    (817, 'MARSHAL', 84, 7, W_CANNON, 3, 'COMMAND GUARD WITH', 'A PLASMA CANNON.'),
    (856, 'DREADNOUGHT', 120, 4, W_CANNON, 2, 'SIEGE DROID.', 'VERY SLOW, VERY TOUGH.'),
    (908, 'PREFECT', 100, 8, W_CANNON, 3, 'THE SHIP MIND\'S', 'OWN BODYGUARD.'),
    (960, 'OVERMIND', 160, 7, W_CANNON, 3, 'THE ROGUE SHIP MIND', 'IN A BATTLE FRAME.'),
]

NTYPES = len(ROSTER)
TYPE_OF = {r[0]: i for i, r in enumerate(ROSTER)}


def cls(num):
    return num // 100


def score_value(num):
    """points for destroying (BCD-friendly multiples of 10)"""
    return 50 + cls(num) * 75


def body_colour(num):
    """MZ colour of a hostile droid's body by class"""
    c = cls(num)
    if c <= 2:
        return 4      # green
    if c <= 5:
        return 5      # cyan
    if c <= 7:
        return 3      # magenta
    return 2          # red
