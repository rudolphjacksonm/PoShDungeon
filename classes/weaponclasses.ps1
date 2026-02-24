
function Get-Weapon {
    Param(
        $WeaponName
    )

        switch ($WeaponName) {
            
            Broken_Shortsword {
                $weaponObj = @{
                    Name = 'Broken_Shortsword'
                    minDamage = 1
                    maxDamage = 4
                    Description = @"

  |A rusty sword hilt with 
  |a few inches of steel still protruding.
  |It has some jagged edges that
  | might scratch someone.
"@
                    Image =  @"
      /\
     /  \
    /_/\ \
      ||_|
      ||
"@
                }
            }

            Short_Sword {
                $weaponObj = @{
                    Name = 'Short_Sword'
                    minDamage = 3
                    maxDamage = 9
                    Description = @"
                    
  |A short blade with a sturdy iron hilt. The pommel is decorated with
  |a crescent surrounding a small skull.
"@
                    Image = @"
       /\
      /  \
      ||||
      ||||
      /__\
"@
                }
            }

            Hatchet {
                $weaponObj = @{
                    Name = 'Hatchet'
                    minDamage = 5
                    maxDamage = 7
                    Description = @"

  |A wedge of honed iron attached to a polished wood pole.
  |It's not the most refined weapon but it will do.
"@
                    Image = @"
      ___
   __/___\__
      | | 
      | |____
      |_____/
"@
                }
            }

            Long_Sword {
                $weaponObj = @{
                    Name = 'Long_Sword'
                    minDamage = 8
                    maxDamage = 14
                    Description = @"

  |A long, steel blade in a steel hilt. It's been polished to a 
  |mirrored reflection and reaches quite far.
"@
                    Image = @"
        /\
       /  \
      / /\ \
      ||  ||
      ||  ||
      ||__||
       /__\
"@
                }
            }

            Zweihander {
                $weaponObj = @{
                    Name = 'Zweihander'
                    minDamage = 9
                    maxDamage = 20
                    Description = @"

  |A heavy steel blade that requires two hands to weild.
  |Can easily cleave through bone.
"@
                    Image = @"
         /\
        /  \
       / /\ \
      / /  \ \
      || || ||
      ||_||_||
        /__\
"@
                }
            }

            Laser_Rifle {
                $weaponObj = @{
                    Name = 'Laser_Rifle'
                    minDamage = 20
                    maxDamage = 34
                    Description = @"

  |A pre-collapse beam rifle with a cracked battery.
  |It still vaporizes most things in one bright flash.
"@
                    Image = @"
    ____________________
   / ________________ /|
  / /______________/ / |
 | |  LASER RIFLE  | | |
 | |______________ | |/
  \________________\/
"@
                }
            }

            Moonblade {
                $weaponObj = @{
                    Name = 'Moonblade'
                    minDamage = 16
                    maxDamage = 28
                    Description = @"

  |A curved silver blade that hums in the dark.
  |Legends say it was forged from moonlight.
"@
                    Image = @"
        _..._
     .-'_..._''.
   .' .'      '.\
  / .'          |
  | |      _    |
  \ '.   .' '. /
   '. `'      /
     `-.___.-'
"@
                }
            }

            Atomic_Bomb {
                $weaponObj = @{
                    Name = 'Atomic_Bomb'
                    minDamage = 75
                    maxDamage = 120
                    Description = @"

  |A tiny warhead in a padded crate.
  |The warning label just says 'NO'.
"@
                    Image = @"
        _.-._
      .' | | '.
     /   | |   \
    |    | |    |
    |  .-===-.  |
     \  '---'  /
      '._|_|_.'
         /_\
"@
                }
            }

            Default {
                Write-Output 'Not a valid weapon.'
            }
        }
    
    # Spit out hash table

    $weaponObj

}

function Equip-Weapon {
    Param(
        $Hero,
        [hashtable]$Weapon
    )

    $Hero.Weapon = $Weapon.Name
    $Hero.WeaponStats = $Weapon

}
