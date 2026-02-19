# Enumerator for valid states
Enum State {
    Dead
    Alive
    Undead

}

# Enumerator for armor types
Enum Armor {
    Cloth_Sack = 0
    Ragged_Leather_Coat = 5
    Rusty_Chainmail = 10
    Dented_Breastplate = 12
}

class Creature {

    # Properties
    [int]$Health
    [int]$MaxHealth
    [string]$Name
    [State]$Status
    [double]$DamageModifier = 1.0
    [double]$HealModifier = 1.0
    [bool]$IsBoss = $false
    
    # Hidden Properties
    hidden [string] $Weakness

    # Parameterless Constructor
    Creature () {
    }

    # Hit creature method
    [void] Hit ([int]$Health) {
        $this.health -= $health

        if ($this.Health -le 0){
            $this.Health = 0
            $this.SetStatus('Dead')
        }

    }

    # Heal creature method
    [void] Heal ([int]$Heal) {
        $this.health += $Heal
        if (($this.MaxHealth -gt 0) -and ($this.Health -gt $this.MaxHealth)) {
            $this.Health = $this.MaxHealth
        }

    }

    # Set status method
    [void] SetStatus ([string] $Status) {
        $this.status = $Status

    }
}

class Orc : Creature {

    # Properties for Orc class
    [int]$Health = 100
    [int]$MaxHealth = 100
    [State]$Status = 'Alive'

    # Hidden properties
    hidden [string] $Weakness = 'Fire'

    # Parameterless constructor
    Orc (){}

    # Constructor w/ name of Orc
    Orc ([string]$name) {
        $this.Name = $Name

    }

    # Constructor w/ name, health of Orc
    Orc ([string]$name,$health) {
        $this.Name = $Name
        $this.Health = $Health
        $this.MaxHealth = $Health

    }
}

class Human : Creature {
    
    # Properties for Human class
    [int]$Health = 80
    [int]$MaxHealth = 80
    [State]$Status = 'Alive'

    # Hidden properties for Human class
    hidden [string] $Weakness = 'Dark'

    Human(){}

    Human ([string]$Name) {
        $this.Name = $Name

    }

    Human ([string]$Name, $Health) {
        $this.Name = $Name
        $this.Health = $Health
        $this.MaxHealth = $Health

    }
}

class Hero : Human {

    # Properties for hero class
    [String]$Armor
    [String]$Weapon
    [string]$Ring
    [int]$Gold = 0
    [int]$Potions = 0
    [int]$Level = 1
    [int]$Experience = 0
    [int]$CritChance = 5
    [int]$DodgeChance = 0
    [double]$HealPowerModifier = 1.0
    [int]$BonusDamage = 0
    
    # Hidden properties
    hidden [hashtable]$WeaponStats
    hidden [hashtable]$ArmorStats

    Hero ([String]$Name) {
        $this.Name = $Name
    }
    
    Hero ([String]$Name, [String]$Armor) {
        $this.Name = $Name
        $this.Armor = $Armor

    }

    Hero ([String]$Name, [String]$Armor, [String]$Weapon) {
        $this.Name = $Name
        $this.Armor = $Armor
        $this.Weapon = $Weapon

    }
}

class Skeleton : Creature {

    # Properties
    [int]$Health = 20
    [int]$MaxHealth = 20
    [state]$Status = 'Undead'

    Skeleton(){}

    Skeleton ([string] $Name) {
        $this.Name = $Name

    }

    Skeleton ([string] $Name, [int] $Health) {
        $this.Name = $Name
        $this.Health = $Health
        $this.MaxHealth = $Health
    
    }
}
