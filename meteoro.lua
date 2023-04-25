local curBlankId = 0

local function cwd()
    local thisFile = debug.getinfo(1).source:sub(2)
    return thisFile:gsub("^(.+\\)[^\\]+$", "%1")
end

local function lapStringToMs(lapString)
    
    local timeComponents = lapString:gsub("%.", ":"):split(":")

    for i = 1, 3 do
        if (tonumber(timeComponents[i], 10) == nil) then
            return nil
        end
    end 

    return timeComponents[3] + timeComponents[2] * 1000 + timeComponents[1] * 60 * 1000
end


local function getNextBlankId()
    curBlankId = curBlankId + 1
    return string.rep(" ", curBlankId)
end

local alien2 = ffi.load(cwd() .. "alien2.dll")

ffi.cdef[[
    void lj_disablePitLimiter(bool active);
    void lj_overrideLapTime(int time);
    void lj_setGripMultiplier(float multiplier);
    void lj_setNoclip(bool active);
    double lj_getGearRatio(int gear);
    void lj_setGearRatio(int gear, double ratio);
    void lj_resetGearRatios();
]]

local settings = {

    

    handling = {
        optimalTireTemp = true,
        gripMultiplier = 1.25,
        gripMultiplierOne = false,
        downforceAdd = 0.0,
    },

    power = {
        passiveExtra = 0.0,
        nos = 0.0,
        brake = 8.0,
        injectNosStart = -1,
        injectNosBoosting = false
    },

    drivetrain = {
        gearRatios = {}
    },

    autopilot = {
        enabled = false,
        skill = 75,
        aggressiveness = 50
    },

    lap = {
        fuelFreeze = -1,
        shouldOverride = false,
        lapTimeString = ""
    },

    misc = {
        disablePitLimiter = false,
        disableDamage = false,
        noclip = false
    }

}
local ab = false;
local localCar;
local localCarState;
local powerClutch;
local seconds = 0;
local rpmBeforeClutch;
local angularVelocity;
local slipAngle;
local slipAngleHandbrake;
local angularVelocityHandBrake = 0;
local activeClutch;
local rpm = 0;
local limitRpm = 4500;
local ratiozera = alien2.lj_getGearRatio(1);
local sound_nos_start = ac.AudioEvent.fromFile({ filename = cwd() .. "nos_engage.wav", use3D = true, loop = false }, true)
local sound_nos_loop = ac.AudioEvent.fromFile({ filename = cwd() .. "nos_loop.wav", use3D = true, loop = true }, true)



function script.windowMain(dt)

    ui.tabBar("main_tabs", function()

        ui.tabItem("Power", function()

            ui.text("Passive power")
            local currentPassive, hasChangedPassive = ui.slider(getNextBlankId(), settings.power.passiveExtra, 0, 50, "%.1f m/s²")
            if hasChangedPassive then
                settings.power.passiveExtra = currentPassive
            end

            ui.text("Passive brake")
            local currentBrake, hasChangedBrake = ui.slider(getNextBlankId(), settings.power.brake, 0, 50, "%.1f m/s²")
            if hasChangedBrake then
                settings.power.brake = currentBrake
            end
          
            ui.text("NoS power (Flash headlights)")
            local currentNoS, hasChangedNoS = ui.slider(getNextBlankId(), settings.power.nos, 0, 50, "%.1f m/s²")
            if hasChangedNoS then
                settings.power.nos = currentNoS
            end

        end)

        ui.tabItem("Handling", function()

            if ui.checkbox("Optimal tire temperatures", settings.handling.optimalTireTemp) then
                settings.handling.optimalTireTemp = not settings.handling.optimalTireTemp
            end
            local cl = 0
            if ac.getJoystickAxisValue(1, 6) ~= 1 then
                cl = (ac.getJoystickAxisValue(1, 6) - 1) * -1
            end
            --ui.text("clutch " .. ac.getJoystickAxisValue(1, 6))
            ui.text("clutch " .. cl)         
            --ui.text("ab " .. (ab and "true" or "false"))         
            
            --ui.text("joystick 1" .. ac.getJoystickName(1))
            --ui.text("joystick val " .. ac.getJoystickAxisValue(1, 6))         
           -- ui.text("local Velocity " .. localCar.localVelocity.z .. " " .. localCar.localVelocity.x .. " " .. localCar.localVelocity.y)   
            --ui.text("Angular Velocity " .. localCar.localAngularVelocity.z .. " " .. localCar.localAngularVelocity.x .. " " .. localCar.localAngularVelocity.y)  
           -- ui.text("Angular Velocity " .. angularVelocity)  
          --  ui.text("Angular Velocity " .. localCar.gas)  
          ui.text("Angular Velocity " .. localCar.wheels[0].angularSpeed )  
          ui.text("SlipAngle " .. localCar.wheels[0].slipAngle )
            ui.text("Grip multiplier")
            local currentGrip, hasChangedGrip = ui.slider(getNextBlankId(), settings.handling.gripMultiplier, 0, 15, "%.2fx")
            if hasChangedGrip then
                settings.handling.gripMultiplier = currentGrip
                alien2.lj_setGripMultiplier(currentGrip)
            end

            ui.text("power time " .. ac.getSim().time .. " " .. seconds)
            
            if ui.checkbox("Grip X1", settings.handling.gripMultiplierOne) then
                settings.handling.gripMultiplier = 1;
                alien2.lj_setGripMultiplier(1)
            end

            if ui.checkbox("POWER CLUTCH", powerClutch) then
                powerClutch = not powerClutch
            end

            ui.text("Downforce add")
            local currentDownforce, hasChangedDownforce = ui.slider(getNextBlankId(), settings.handling.downforceAdd, 0, 3000, "%.0fkg")
            if hasChangedDownforce then
                settings.handling.downforceAdd = currentDownforce * 2
            end
            
           

        end)

        ui.tabItem("Drivetrain", function()

            for gear = 0, localCar.gearCount do
                local gearName = gear == 0 and "R" or gear
                settings.drivetrain.gearRatios[gear] = alien2.lj_getGearRatio(gear)

                ui.text("Gear " .. gearName)
                local currentGearRatio, hasChangedGearRatio = ui.slider(getNextBlankId(), settings.drivetrain.gearRatios[gear], -5, 8, "%.4f", 2)
                if hasChangedGearRatio then

                    alien2.lj_setGearRatio(gear, currentGearRatio)
                end

            end

            if ui.button("Reset") then
                alien2.lj_resetGearRatios()
            end

        end)

        ui.tabItem("Auto-pilot", function()

            if ui.checkbox("Enabled", settings.autopilot.enabled) then
                settings.autopilot.enabled = not settings.autopilot.enabled
                physics.setCarAutopilot(settings.autopilot.enabled)
                
            end

            ui.text("Skill")
            local currentSkill, hasChangedSkill = ui.slider(getNextBlankId(), settings.autopilot.skill, 0, 100, "%.0f%%")
            if hasChangedSkill then
                settings.autopilot.skill = currentSkill
                physics.setAILevel(0, currentSkill / 100)
            end

            ui.text("Aggressiveness")
            local currentAggressiveness, hasChangedAggressiveness = ui.slider(getNextBlankId(), settings.autopilot.aggressiveness, 0, 100, "%.0f%%")
            if hasChangedAggressiveness then
                settings.autopilot.aggressiveness = currentAggressiveness
                physics.setAIAggression(0, currentAggressiveness / 100)
            end

        end)

        ui.tabItem("Lap", function()
            
            if ui.checkbox("Freeze fuel amount", settings.lap.fuelFreeze >= 0) then
                settings.lap.fuelFreeze = settings.lap.fuelFreeze > 0 and -1 or localCar.fuel
                
            end
            
            local hasEnabledOverride = false
            if ui.checkbox("Override lap time", settings.lap.shouldOverride) then
                settings.lap.shouldOverride = not settings.lap.shouldOverride

                if settings.lap.shouldOverride then
                    settings.lap.lapTimeString = ac.lapTimeToString(localCar.lapTimeMs)
                    hasEnabledOverride = true
                else
                    alien2.lj_overrideLapTime(0)
                end

            end

            if settings.lap.shouldOverride then
                local currentTime, hasChangedTime = ui.inputText(" ", settings.lap.lapTimeString)
                if hasChangedTime or hasEnabledOverride then
                    settings.lap.lapTimeString = currentTime
                    local overrideLapMs = lapStringToMs(currentTime)

                    if overrideLapMs ~= nil then
                        alien2.lj_overrideLapTime(overrideLapMs)
                    end
                end

            end

            ui.text("* Laps will never be invalid with Alien V2 running")
        end)

        ui.tabItem("Misc", function()
          
            if ui.checkbox("Disable pit speed limiter", settings.misc.disablePitLimiter) then
                settings.misc.disablePitLimiter = not settings.misc.disablePitLimiter
                alien2.lj_disablePitLimiter(settings.misc.disablePitLimiter)
            end

            if ui.checkbox("Disable body and engine damage", settings.misc.disableDamage) then
                settings.misc.disableDamage = not settings.misc.disableDamage
            end

            if ui.checkbox("No collisions", settings.misc.noclip) then
                settings.misc.noclip = not settings.misc.noclip
                alien2.lj_setNoclip(settings.misc.noclip)
            end
            
        end)

    end)

end

function script.update(dt)    
    localCar = ac.getCar(0)        
    

    if ac.getJoystickAxisValue(1, 6) == 0 then
        activeClutch = true        
    else
        rpmBeforeClutch = localCar.rpm
        activeClutch = false
    end

    local cl = 0
    if ac.getJoystickAxisValue(1, 6) ~= 1 then
        cl = (ac.getJoystickAxisValue(1, 6) - 1) * -1
    end

    local handBrake = ac.getJoystickAxisValue(0, 6) + 2
    

    sound_nos_start:setPosition(localCar.position, nil, nil, localCar.velocity)
    sound_nos_loop:setPosition(localCar.position, nil, nil, localCar.velocity)

    if settings.handling.optimalTireTemp then
        local temp = ac.getCar(0).wheels[0].tyreOptimumTemperature
        physics.setTyresTemperature(0, ac.Wheel.All, temp)
    end

    if settings.misc.disableDamage then
        physics.setCarBodyDamage(0, vec4(0, 0, 0, 0))
        physics.setCarEngineLife(0, 1000)
    end

    if settings.handling.downforceAdd > 0 then
        physics.addForce(0, vec3(0, 0, 0), true, vec3(0, -settings.handling.downforceAdd * 9.8 * dt * 100, 0), true)
    end


    if localCar.wheels[0].slipAngle > 9 or localCar.wheels[0].slipAngle < -9 then
        alien2.lj_setGripMultiplier(1.47)
        if localCar.gas > 0 then            
            local passivePush = 3 * (localCar.gear - 1) * localCar.mass * 1 * dt * 100
            physics.addForce(0, vec3(0, 0, 0), true, vec3(0, 0, passivePush), true) 
        end
    end

    if localCar.wheels[0].slipAngle > 20 or localCar.wheels[0].slipAngle < -20 then
        alien2.lj_setGripMultiplier(1.60)
        if localCar.gas > 0 then            
            local passivePush = 4 * (localCar.gear - 1) * localCar.mass * 1 * dt * 100
            physics.addForce(0, vec3(0, 0, 0), true, vec3(0, 0, passivePush), true) 
            ab = true
        end
    else
        ab = false
        alien2.lj_setGripMultiplier(settings.handling.gripMultiplier)
    end

    if cl > 0 and localCar.gas < 0.6 and localCar.wheels[0].angularSpeed > 0 and (math.floor(localCar.wheels[0].slipAngle) > 1 or math.floor(localCar.wheels[0].slipAngle) < -1) then
        
        if localCar.wheels[0].slipAngle ^ 0 ~= slipAngle ^ 0 and localCar.wheels[0].slipAngle > 2 * x  then
            x = x * -1
            physics.addForce(0, vec3(x, 0, 1), true, vec3(x * -fuerza, 0, 0), true) 
        end

        local x = slipAngle >= 0 and 1 or -1
        
        local variante = 30

        local alpha = (variante * 3.14159265 ) / 2
        local inercia = 0.5 * localCar.mass
    
        local speed = (localCar.speedKmh < 60 or localCar.speedKmh > -60) and 60 * x or localCar.speedKmh
        if speed < 0 then
            speed = speed * -1
        end

        local total = inercia * alpha * cl
        if total < 0 then
            total  = total * -1
        end

        local fuerza = total + speed
        physics.addForce(0, vec3(x, 0, 1), true, vec3(x * -fuerza, 0, 0), true)               

        if localCar.wheels[0].slipAngle ^ 0 ~= slipAngle ^ 0 and localCar.wheels[0].slipAngle > 2 * x  then
            x = x * -1
            physics.addForce(0, vec3(x, 0, 1), true, vec3(x * -fuerza, 0, 0), true) 
        end
    else
        slipAngle = localCar.wheels[0].slipAngle
        angularVelocity = localCar.wheels[0].angularSpeed
    end

    if handBrake > 1 then     
        local x = slipAngleHandbrake >= 0 and 1 or -1
    
        local alpha = (10 * 3.14159265 ) / 2
        local inercia = 0.5 * localCar.mass
    
        local speed = (localCar.speedKmh < 120 or localCar.speedKmh > -120) and 200 * x or localCar.speedKmh
        if speed < 0 then
            speed = speed * -1
        end

        local total = inercia * alpha * handBrake
        if total < 0 then
            total  = total * -1
        end

        local fuerza = total + speed
        physics.addForce(0, vec3(x, 0, 1), true, vec3(x * fuerza, 0, 0), true)         
        physics.addForce(0, vec3(x, 0, -1), true, vec3(x * -fuerza/2, 0, 0), true)         
    else
        slipAngleHandbrake = localCar.wheels[0].slipAngle
        angularVelocityHandbrake = localCar.wheels[0].angularSpeed
    end


    if settings.power.brake > 0 and (localCar.speedKmh > 5) then
        local passivePush = settings.power.brake +  (1.4  ^ 3)  * localCar.mass * localCar.brake * dt * 100
        passivePush = localCar.localVelocity.z > 0.0 and -passivePush or passivePush
        
        physics.addForce(0, vec3(0, 0, 0), true, vec3(0, 0, passivePush), true)
    end

    if settings.power.brake > 0 and (localCar.speedKmh > 5) then
        local passivePush = settings.power.brake +  (1.4  ^ localCar.gear) * localCar.mass * localCar.handbrake * dt * 100
        passivePush = localCar.localVelocity.z > 0.0 and -passivePush or passivePush
        physics.addForce(0, vec3(0, 0, 0), true, vec3(0, 0, passivePush), true)
    end    
    
    if settings.lap.fuelFreeze >= 0 then
        physics.setCarFuel(0, settings.lap.fuelFreeze)
    end

    if localCar.gear > 1 and localCar.rpm < limitRpm and localCar.gas > 0.9 then
        physics.setEngineRPM(0, limitRpm)
    end

    if localCar.gear == 1 and localCar.gas > 0.9 and localCar.rpm < limitRpm then
        physics.setEngineRPM(0, limitRpm)
    end

    if cl == 2 and (localCar.gear > 0) and localCar.gas > 0 and localCar.handbrake < 0.9 then
        powerClutch = true
        seconds = ac.getSim().time + 4000
        if settings.power.injectNosStart < 0 then
            settings.power.injectNosStart = ac.getSim().time
            sound_nos_start:start()
            sound_nos_loop:start()  
        end
    end

    if seconds > ac.getSim().time then
        if settings.power.injectNosStart < 0 then
            settings.power.injectNosStart = ac.getSim().time
            sound_nos_start:start()
        end

        if ac.getSim().time > settings.power.injectNosStart + 100 then
            if not settings.power.injectNosBoosting then
                sound_nos_start:stop()
                sound_nos_loop:start()
                settings.power.injectNosBoosting = true
            end

            local nosPush = settings.power.nos + (1.4  ^ localCar.gear)  * localCar.mass * localCar.gas * dt * 100
            physics.addForce(0, vec3(0, 0, 0), true, vec3(0, 0, nosPush), true)
        
            if ac.getSim().firstPersonCameraFOV < 75 then
                ac.setFirstPersonCameraFOV(ac.getSim().firstPersonCameraFOV + 6 * dt)
            end
        end
    else
        powerClutch = false
        settings.power.injectNosStart = -1
        settings.power.injectNosBoosting = false
        sound_nos_start:stop()
        sound_nos_loop:stop()
        ac.resetFirstPersonCameraFOV()
    end
    
    if  (localCar.gear > 1) and (localCar.rpm + 200 < localCar.rpmLimiter) then       
        local rpmlim = 0
        if localCar.rpm  > 3000 then
            rpmlim = 0.1
        end
        if localCar.rpm  > 5500 then
            rpmlim = 0.2
        end
        if localCar.rpm > 7000 then
            rpmlim = 0.3
        end
        local passivePush = (settings.power.passiveExtra + rpmlim) * (localCar.gear - 1) * localCar.mass * localCar.gas * dt * 100        
        physics.addForce(0, vec3(0, 0, 0), true, vec3(0, 0, passivePush), true)
    end


    if localCar.flashingLightsActive and settings.power.nos > 0 and (localCar.gear > 0) then
        if settings.power.injectNosStart < 0 then
            settings.power.injectNosStart = ac.getSim().time
            sound_nos_start:start()
        end

        if ac.getSim().time > settings.power.injectNosStart + 700 then
            if not settings.power.injectNosBoosting then
                sound_nos_start:stop()
                sound_nos_loop:start()
                settings.power.injectNosBoosting = true
            end

            local nosPush = settings.power.nos * localCar.mass * localCar.gas * dt * 100
            physics.addForce(0, vec3(0, 0, 0), true, vec3(0, 0, nosPush), true)
            
            if ac.getSim().firstPersonCameraFOV < 75 then
                ac.setFirstPersonCameraFOV(ac.getSim().firstPersonCameraFOV + 6 * dt)
            end
        end
        
    elseif powerClutch == false and settings.power.injectNosStart > 0 then
        settings.power.injectNosStart = -1
        settings.power.injectNosBoosting = false
        sound_nos_start:stop()
        sound_nos_loop:stop()
        ac.resetFirstPersonCameraFOV()
    end

end