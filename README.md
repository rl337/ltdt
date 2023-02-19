# la tempête du temps


## Intention
The purpose of this project is to buid out an end-to-end game workflow whose components will eventually be completely replaced by a "text-to-game" engine.

Until a complete text-to-game engine exists, coded aspects of the project will be created with the Godot Engine.

## Organization
The project will be divided into several workflow steps.

1. *Initialization*  This step primes the workspace.  Cleans up artifacts from previous builds.  Creates required directory structure.  Based on repository and/or branch structure features are selected to be part of the workflow.
2. *Generative* This step produces generative artifacts based on the features selected by initialization.  Whenever possible public APIs are used and assets are created on-demand.  Ideally AI prompts and calls to generative AI services are the only things checked in.
3. *Build* Once all generative assets are in place actually build the game.
4. *Packaging* Produce appropriately packaged "application" for a matrix of platforms.
5. *Publish* Make application versions available

These steps should be orchestrated in the most straight forward manner possible avoiding clever or efficient methods in favor of readability.

## Licensing

While one goal of the project is to only store prompts to generative services, practically speaking won't always be possible.  Any generative asset checked in will be subject to the licensing constraints of the service that generated them.  Those licenses will be checked into this repository and referenced from this document.

* Stable Diffusion - Stable Diffusion ML License (LICENSE.stable-diffusion-license)
* Blockade Labs - Stable Diffusion ML License (LICENSE.stable-diffusion-license)
* This project's code and produced artifacts - Creative Commons Attribution 4.0 International Public License (LICENSE.cc-by-40-license)
* Godot Game Engine is licensed under an MIT License derivative - https://godotengine.org/license/
