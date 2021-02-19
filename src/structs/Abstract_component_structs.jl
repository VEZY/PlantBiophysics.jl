# AbstractScene (the upper one)
"""
Used to describe a scene, the higher spatial representation for a simulation. A scene
usually contains objects such as plants, soils, solar panels....
"""
abstract type AbstractScene end

# AbstractObject
"""
Used to describe objects in a scene (*e.g.* plants, soils, solar panels...).
"""
abstract type AbstractObject <: AbstractScene end

# Components
"""
Used to describe object components (*e.g.* leaves, metamers...).
"""
abstract type AbstractComponent <: AbstractObject end

# Photosynthetic components
"""
Used to describe photosynthetic components.
"""
abstract type AbstractPhotoComponent <: AbstractComponent end
