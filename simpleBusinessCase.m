function varargout=simpleBusinessCase(massGross,vCruise,nPax,varargin)
ip=inputParser;

%Required inputs constraints
addRequired(ip, 'massGross',  @isnumeric);                                  %Gross takeoff mass [kg]
addRequired(ip, 'vCruise',    @isnumeric);                                  %Cruise speed [m/s]
addRequired(ip, 'nPax',       @isnumeric);                                  %Number of passengers

%UAM constraints
addParameter(ip, 'dValue',          14,         @isnumeric);                %D-value for vehicle [m]
addParameter(ip, 'pilot',           0,          @isnumeric);                %Number of pilots (non-paying passengers)
addParameter(ip, 'timeValue',       3/60,       @isnumeric);                %Premium market value of time [$/s]
addParameter(ip, 'distanceValue',   3.5/1000,   @isnumeric);                %Ticket price charged per distance [$/m]
addParameter(ip, 'flightTimeValue', 0.25,       @isnumeric);                %Ticket price per time [$/s]
addParameter(ip, 'ticketModel',     'all',      @ischar);                   %Ticket price model.
                                                                            %   value: based on time value
                                                                            %   distance: based on trip distance
                                                                            %   time: based on flight time
                                                                            %   all: based on minimum of all

%Physical constants
addParameter(ip, 'rho',     1.225,      @isnumeric);                        %Air density [kg/m^3]
addParameter(ip, 'g',       9.80665,    @isnumeric);                        %Gravity [m/s^2]
addParameter(ip, 'vSound',  340.29,     @isnumeric);                        %Reference speed of sound

%Vehicle Specifications
addParameter(ip, 'emptyFraction',       0.60,                 @isnumeric);  %Empty mass fraction
addParameter(ip, 'pilotMass',           100,                  @isnumeric);  %Total pilot mass including equipment [kg]
addParameter(ip, 'paxMass',             nan,                  @isnumeric);  %Mass allowance per passenger (including luggage) [kg]
addParameter(ip, 'hoverEfficiency',     0.93*0.98*0.98,       @isnumeric);  %Hover propeller efficiency (motor+controller+line)
addParameter(ip, 'hoverKappa',          1.1,                  @isnumeric);  %Account for induced tip losses
addParameter(ip, 'areaRotorFraction',   0.32,                 @isnumeric);  %Fraction of d-value area occupied by rotor disks
addParameter(ip, 'bladeCl',             0.80,                 @isnumeric);  %Blade average cl
addParameter(ip, 'bladeCd',             0.02,                 @isnumeric);  %Blade average cd
addParameter(ip, 'tipMach',             0.5,                  @isnumeric);  %Hover tip speed limit
addParameter(ip, 'solidityLimits',      [0.06 0.25],          @isnumeric);  %Minimum solidity
addParameter(ip, 'cruiseEfficiency',    0.90*0.96*0.98*0.81,  @isnumeric);  %Cruise propeller efficiency (motor+controller+line+efficiency)
addParameter(ip, 'cruiseCl',            0.55,                 @isnumeric);  %Cruise lift coefficient
addParameter(ip, 'ARmax',               12,                   @isnumeric);  %Maximum aspect ratio (for stiffness & weight)
addParameter(ip, 'Cd0',                 0.045,                @isnumeric);  %Aircraft drag coeff

%Propulsion System
addParameter(ip, 'nMotors',                 8,                @isnumeric);  %Number of motors
addParameter(ip, 'cellSpecificEnergy',      240*3600,         @isnumeric);  %Specific energy of cell [Ws/kg]
addParameter(ip, 'integrationFactor',       0.70,             @isnumeric);  %Integration factor for (pack energy vs cell energy)
addParameter(ip, 'endOfLifeFactor',         0.80,             @isnumeric);  %Factor to define pack end of life
addParameter(ip, 'cycleLifeFactor',         8424,             @isnumeric);  %Battery pack degradation factor (cycles=cycleLifeFactor*exp(-depthDegradationRate*dischargeDepth)/avgDischargeRate)
addParameter(ip, 'depthDegradationRate',    3.180,            @isnumeric);  %Battery pack degradation factor (cycles=cycleLifeFactor*exp(-depthDegradationRate*dischargeDepth)/avgDischargeRate)
addParameter(ip, 'reserveEnergyFactor',     0.15,             @isnumeric);  %Reserve energy in pack (including unusable)

%Mission Specifications
addParameter(ip, 'vHeadwind',   5,      @isnumeric);                        %Headwind [m/s]
addParameter(ip, 'tHover',      3*60,   @isnumeric);                        %Time spent in hover [s]
addParameter(ip, 'tAlternate',  10*60,  @isnumeric);                        %Maximum time spent in alternate [s]
addParameter(ip, 'dAlternate',  15e3,   @isnumeric);                        %Maximum distance covered for an alternate [km]

%Alternate Reference Mission Specifications
addParameter(ip, 'dMission',    nan,    @isnumeric);                        %Maximum time spent in alternate [s]

%Operations Specifications
addParameter(ip, 'operatingTimePerDay',         8*3600, @isnumeric);        %Hours of operation per day [s/day]
addParameter(ip, 'scheduledAvailabilityRate',   0.90,   @isnumeric);        %Rate that vehicle is in scheduled operation
addParameter(ip, 'unscheduledAvailabilityRate', 0.90,   @isnumeric);        %Rate that vehicle is available (e.g. weather)
addParameter(ip, 'padTurnAroundTime',           5*60,   @isnumeric);        %Time between landing and takeoff [s]
addParameter(ip, 'deadheadRate',                0.3,    @isnumeric);        %Percentage of trips that are deadhead
addParameter(ip, 'operatingCostFactor',         0.30,   @isnumeric);        %Costs in addition to DOC and landing fees

%Cost Specifications
addParameter(ip, 'specificBatteryCost',     250/3600/1000,  @isnumeric);    %Total pack specific cost [$/Ws]
addParameter(ip, 'costElectricity',         0.20/1000/3600, @isnumeric);    %Cost of electricty [$/Ws]
addParameter(ip, 'specificHullCost',        550,            @isnumeric);    %Specific cost of the vehicle [$/kg]
addParameter(ip, 'depreciationRate',        0.1,            @isnumeric);    %Annual depreciation rate [% of hull cost]
addParameter(ip, 'costLiabilityPerYear',    22000,          @isnumeric);    %Annual liability cost [$/year]
addParameter(ip, 'hullRatePerYear',         0.045,          @isnumeric);    %Annual hull insurance rate [% of hull cost]
addParameter(ip, 'annualServicesFees',      7700,           @isnumeric);    %Annual fees for maintenance, navigation, datalink [$/year]
addParameter(ip, 'maintananceCostPerFH',    100,            @isnumeric);    %Maintenance cost per FH [$/FH]
addParameter(ip, 'landingFee',              50,             @isnumeric);    %Cost per landing
addParameter(ip, 'pilotCostRate',           280500,         @isnumeric);    %Annual pilot cost (including benefits)
addParameter(ip, 'trainingCostRate',        9900,           @isnumeric);    %Annual training cost

%Customer Experience
addParameter(ip, 'taxiPriceRate',           1.5/1000,   @isnumeric);        %Taxi ticket price per km [$/m]
addParameter(ip, 'lastLegDistance',         3000,       @isnumeric);        %Distance to drive from helipad to destination
addParameter(ip, 'curbTime',                16*60,      @isnumeric);        %Time to transfer from gate to curb [s]
addParameter(ip, 'unloadTime',              1*60,       @isnumeric);        %Time to unload from taxi [s]
addParameter(ip, 'transferTime',            24*60,      @isnumeric);        %Time to transfer from gate to helipad including security [s]
addParameter(ip, 'alightTime',              4*60,       @isnumeric);        %Time to alight and get to curb [s]

%Output data request
addParameter(ip, 'out',        {'profitPerYear'},       @iscell);           %Time to alight and get to curb [s]

%Inputs
parse(ip,massGross,vCruise,nPax,varargin{:});   %Parse inputs
p=ip.Results;                                   %Store results structure
unit=ones(size(p.massGross));                   %Ones matrix

%Handle inputs of different dimensions
if numel(p.massGross)==1 && numel(p.vCruise)>1
    p.massGross=ones(size(p.vCruise))*p.massGross;
end

if numel(p.massGross)>1 && numel(p.vCruise)==1
    p.vCruise=ones(size(p.massGross))*p.vCruise;
end

if size(p.massGross,1)~=size(p.vCruise,1) || size(p.massGross,2)~=size(p.vCruise,2)
    error('Dimensions of massGross and vCruise must be the same, unless one has numel=1')
end

%Passenger mass
if isnan(p.paxMass)
    meanPaxMass=111;                                                        %Mean passenger mass (winter with carryon)[kg]
    devPaxMass=18.6;                                                        %Standard deviation of passenger mass (winter with carryon)[kg]
    pAddressed=0.95;                                                        %Percent of passenger accomodated
    paxMass=meanPaxMass+erfinv(2*pAddressed-1)*sqrt(2/p.nPax)*devPaxMass;   %Mass allowance per passenger (including luggage)
end

%Mass breakdown
payload=p.nPax*paxMass;                                                     %Total passenger mass
massEmpty=p.massGross*p.emptyFraction;                                      %Empty mass [kg]
massBatteries=max(0,p.massGross-massEmpty-payload-p.pilotMass*p.pilot);     %Battery mass [kg]

%Hover performance
tipSpeed=p.vSound*p.tipMach;                                                                    %Rotor tip speed [m/s]
diskArea=(0.25*pi*p.dValue^2)*p.areaRotorFraction/p.nMotors;                                    %Disk area per rotor [m^2]                                                                     
solidity=6*(p.massGross*p.g/p.nMotors)/(p.rho*tipSpeed^2*diskArea*p.bladeCl);                   %Solidity
solidity=median(cat(3,solidity,unit*p.solidityLimits(1),unit*p.solidityLimits(2)),3);           %Apply solidity bounds
tipSpeed=sqrt(6*(p.massGross*p.g/p.nMotors)./(p.rho*diskArea*p.bladeCl*solidity));              %Recompute tip speed based on new solidity
powerInduced=p.nMotors*(p.massGross*p.g/p.nMotors).^1.5/sqrt(2*p.rho*diskArea)*p.hoverKappa;    %Induced power [W]
powerProfile=p.rho*diskArea*tipSpeed.^3.*solidity*p.bladeCd/8;                                  %Profile power [W]
powerHover=(powerInduced+powerProfile)/p.hoverEfficiency;                                       %Total hover power draw [W]

%Cruise performance
sRef=p.massGross*p.g./(0.5*p.rho*p.cruiseCl*p.vCruise.^2);                  %Reference wing area [m^2]
AR=p.dValue^2./sRef;                                                        %Aspect ratio
AR=sum(cat(3,AR,p.ARmax*unit).^-6,3).^(-1/6);                               %Apply aspect ratio upper limit
sRef=p.dValue^2./AR;                                                        %Recompute reference wing area [m^2]
Cl=p.massGross*p.g./(0.5*p.rho*sRef.*p.vCruise.^2);                         %Recompute cruise lift coefficient
oswald=sqrt(1-(p.vCruise/p.vSound).^2)*0.85./(1+0.008*AR);                  %Oswald efficiency factor
cruiseCd=p.Cd0+Cl.^2./(pi*AR.*oswald);                                      %Cruise drag coefficient
lod=Cl./cruiseCd;                                                           %Lift-to-drag ratio
powerCruise=p.massGross*p.g.*p.vCruise./lod/p.cruiseEfficiency;             %Total cruise power draw [W]

%Mission
specificEnergy=p.cellSpecificEnergy*p.integrationFactor*p.endOfLifeFactor;                      %Pack useful specific energy
energyTotal=specificEnergy*massBatteries;                                                       %Usable energy stored in batteries [Ws]
energyAlternate=min(cat(3,powerCruise*p.tAlternate,powerCruise*p.dAlternate./p.vCruise),[],3);  %Energy used during alternate (2 types of alternate considered) [Ws]
energyReserve=energyTotal*p.reserveEnergyFactor;                                                %Reserve energy

if isnan(p.dMission)
    energyMission=energyTotal-powerHover*p.tHover-energyAlternate-energyReserve;        %Remaining energy for mission [Ws]
    energyMission(energyMission<0)=nan;                                                 %Remove infeasible cases
    tCruise=energyMission./powerCruise;                                                 %Cruise time [s]
    tTrip=p.tHover+tCruise;                                                             %Total time spend flying [s]
    range=tCruise.*(p.vCruise-p.vHeadwind);                                             %Maximum mission range [m]
else
    range=p.dMission*unit;                                                              %Set range if user provides reference mission range
    tCruise=range./(p.vCruise-p.vHeadwind);                                             %Time spent in cruise [s]
    energyMission=tCruise.*powerCruise;                                                 %Energy used on mission [s]
    temp=energyMission>energyTotal-powerHover*p.tHover-energyAlternate-energyReserve;   %Find infeasible cases
    energyMission(temp)=nan;                                                            %Remove infeasible cases
    tTrip=p.tHover+tCruise;                                                             %Total time spend flying [s]
    tTrip(temp)=nan;                                                                    %Remove infeasible cases
end

%Operations
tripsPerDay=p.operatingTimePerDay./(tTrip+p.padTurnAroundTime);                             %Number of trips that can be completed in a day
tripsPerYear=365*tripsPerDay*p.scheduledAvailabilityRate*p.unscheduledAvailabilityRate;     %Number of trips completed in 1 year
flightHoursPerYear=tripsPerYear.*tTrip/3600;                                                %Number of flight hours completed in 1 year

%Costs
%Energy Costs
dischargeDepth=(energyMission+powerHover*p.tHover)./energyTotal;                            %Depth of discharge
costBattery=energyTotal*p.specificBatteryCost;                                              %Battery cost [$]
dischargeRate=(p.tHover*powerHover+tCruise.*powerCruise)./tTrip./energyTotal*3600;          %Average mission discharge rate [C]                                       
cycleLife=p.cycleLifeFactor*exp(-p.depthDegradationRate*dischargeDepth)./dischargeRate;     %Number of missions before 80% SOH
packCostPerTrip=costBattery./cycleLife;                                                     %Cost of pack per mission [$/mission]
energyCostPerTrip=p.costElectricity.*energyMission;                                         %Cost of electricity per mission [$/mission]

%Fixed Costs
hullCost=p.specificHullCost*massEmpty;                                                                  %Acquisition cost of aircraft [$]
costInsurancePerYear=p.costLiabilityPerYear+p.hullRatePerYear*hullCost;                                 %Annual insurance cost [$/yr]
costDepreciationPerYear=p.depreciationRate*hullCost;                                                    %Annual depreciation cost [$/yr]
pilotCost=p.pilot*p.pilotCostRate;                                                                      %Annual pilot cost (including benefits)
trainingCost=p.pilot*p.trainingCostRate;                                                                %Annual training cost
annualCost=costInsurancePerYear+costDepreciationPerYear+p.annualServicesFees+pilotCost+trainingCost;    %Annual fixed costs [$/yr]

%Variable Costs
energyCostPerFH=energyCostPerTrip./tTrip*3600;                              %Energy cost per flight hour  [$/FH]
packCostPerFH=packCostPerTrip./tTrip*3600;                                  %Pack cost per flight hour  [$/FH]
variableCost=energyCostPerFH+packCostPerFH+p.maintananceCostPerFH;          %Total variable cost per flight hour  [$/FH]

%Costs Summary
costPerFlightHour=variableCost+(annualCost+p.landingFee*tripsPerYear)./flightHoursPerYear; %Total operating cost per flight hour  [$/FH]
costPerFlightHour=costPerFlightHour*(1+p.operatingCostFactor);

%Customer experience
vDrive=(25+0.4331*range/1000)*1000/3600;                                    %Taxi speed during peak traffic [m/s]
tDrive=p.curbTime+range./vDrive+p.unloadTime;                               %Taxi trip time [s]
drivePrice=p.taxiPriceRate*range;                                           %Taxi ticket price [$]
tFly=p.transferTime+tTrip+p.alightTime+p.lastLegDistance./vDrive;           %UAM trip time [s]

%Model to select UAM trip price
switch p.ticketModel
    case 'value'                                                            %Ticket price based on time value [$]
        flyPrice=p.timeValue*(tDrive-tFly)+drivePrice;
    case 'distance'                                                         %Ticket price based on trip distance [$]
        flyPrice=p.distanceValue*range;
    case 'time'                                                             %Ticket price based on trip time [$]
        flyPrice=p.flightTimeValue*tTrip;
    case 'all'                                                              %Ticket price based on all models [$]
        flyPrice=min(cat(3,p.timeValue*(tDrive-tFly)+drivePrice, ...
            p.distanceValue*range, p.flightTimeValue*tTrip),[],3);
end
temp=flyPrice<0;
flyPrice=flyPrice+p.taxiPriceRate*p.lastLegDistance;                        %Include last leg taxi fare [$]
flyPrice(temp)=nan;                                                         

%Business Case
passengerLoadingRate=1+.1*(1-p.nPax);                                       %Average rate that vehicle is full when flying passengers
revenuePerTrip=flyPrice*nPax*passengerLoadingRate;                          %Revenue per trip [$/mission]
revenuePerFlightHour=revenuePerTrip./(tTrip/3600)*(1-p.deadheadRate);       %Revenue per flight hour [$/FH]
profitPerFlightHour=revenuePerFlightHour-costPerFlightHour;                 %Profit per flight hour [$/FH]
profitPerYear=profitPerFlightHour.*flightHoursPerYear;                      %Annual profit [$/yr]
impliedValue=(flyPrice-drivePrice)./(tDrive-tFly)*60;                       %Otherwise, computer implied value [$ per min saved]
impliedValue(flyPrice>drivePrice & tDrive<tFly)=nan;                        %If aircraft is slower and more expensive then no value

%Data out
for i=1:length(p.out)
    varargout{i}=eval(p.out{i});
end