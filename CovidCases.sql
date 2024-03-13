Select * 
From PortfolioProject.coviddeaths
ORDER BY 3,4;

SET SQL_SAFE_UPDATES = 0;

update PortfolioProject.coviddeaths
set date=str_to_date(date,"%m/%d/%Y");

alter table PortfolioProject.coviddeaths
modify date date;

update PortfolioProject.covidvaccinations
set date=str_to_date(date,"%m/%d/%Y");

alter table PortfolioProject.covidvaccinations
modify date date;

Select * 
From PortfolioProject.covidvaccinations
ORDER BY 3,4;
-- Select * 
-- From PortfolioProject.covidvaccinations
-- ORDER BY 3,4; 

-- Select data we are going to be using 

Select location, date, total_cases, new_cases, total_deaths, population
From PortfolioProject.coviddeaths
Order by 1,2

-- Looking at Total Cases vs Total Deaths 
SELECT location, date, total_cases, total_deaths, (total_deaths/total_cases)*100 as DeathPercentage
From PortfolioProject.coviddeaths
Where location like '%states%'
Order by 1,2;

-- Looking at total cases versus the population 
Select location, date, total_cases, population, (total_cases/population)*100 as PopulationPercentage
From PortfolioProject.coviddeaths
Where location like '%states%'
Order by 1,2;

-- Countries with Highest Infection Rate compared to Population
SELECT 
    location, 
    population, 
    MAX(total_cases) as HighestInfectionCount,  
    MAX((total_cases/population))*100 as PercentPopulationInfected
FROM 
    PortfolioProject.coviddeaths
-- WHERE 
   -- Location LIKE '%states%'
GROUP BY 
    location, population
ORDER BY 
    PercentPopulationInfected DESC;

-- Countries with Highest Death Count per Population
SELECT 
    location, 
    MAX(CAST(total_deaths AS SIGNED)) as TotalDeathCount
FROM 
    PortfolioProject.coviddeaths
WHERE 
    continent IS NOT NULL 
GROUP BY 
    location
ORDER BY 
    TotalDeathCount DESC;

-- BREAKING THINGS DOWN BY CONTINENT
-- Showing continents with the highest death count per population
SELECT 
    continent, 
    MAX(CAST(total_deaths AS SIGNED)) as TotalDeathCount
FROM 
    PortfolioProject.coviddeaths
WHERE 
    continent IS NOT NULL 
GROUP BY 
    continent
ORDER BY 
    TotalDeathCount DESC;

-- GLOBAL NUMBERS
SELECT 
    SUM(new_cases) as total_cases, 
    SUM(CAST(new_deaths AS SIGNED)) as total_deaths, 
    SUM(CAST(new_deaths AS SIGNED))/SUM(New_Cases)*100 as DeathPercentage
FROM 
    PortfolioProject.coviddeaths
WHERE 
    continent IS NOT NULL;

-- Total Population vs Vaccinations
-- Shows Percentage of Population that has received at least one Covid Vaccine
-- SELECT * 
	-- FROM PortfolioProject.coviddeaths dea
    -- JOIN PortfolioProject.covidvaccinations vac
		-- ON dea.location = vac.location
        -- AND dea.date = vac.date;

SELECT 
    dea.continent, 
    dea.location, 
    dea.date, 
    dea.population, 
    vac.new_vaccinations,
    @RollingPeopleVaccinated := SUM(CAST(vac.new_vaccinations AS SIGNED)) OVER (Partition by dea.location Order by dea.location, dea.Date) as RollingPeopleVaccinated
FROM 
    PortfolioProject.coviddeaths dea
JOIN 
    PortfolioProject.covidvaccinations vac
ON 
    dea.location = vac.location
    AND dea.date = vac.date
WHERE 
    dea.continent IS NOT NULL
ORDER BY 
    dea.location, dea.date;

-- Using CTE to perform Calculation on Partition By in previous query
WITH PopvsVac AS (
    SELECT 
        dea.continent, 
        dea.location, 
        dea.date, 
        dea.population, 
        vac.new_vaccinations,
        @RollingPeopleVaccinated := SUM(CAST(vac.new_vaccinations AS SIGNED)) OVER (Partition by dea.location Order by dea.location, dea.date) as RollingPeopleVaccinated
    FROM 
        PortfolioProject.coviddeaths dea
    JOIN 
        PortfolioProject.covidvaccinations vac
    ON 
        dea.location = vac.location
        AND dea.date = vac.date
    WHERE 
        dea.continent IS NOT NULL
)
SELECT 
    *, 
    (RollingPeopleVaccinated/Population)*100
FROM 
    PopvsVac;

-- Using Temp Table to perform Calculation on Partition By in previous query
-- Drop table if exists
DROP TABLE IF EXISTS PercentPopulationVaccinated;

-- Create the table
CREATE TABLE PercentPopulationVaccinated (
    continent VARCHAR(255),
    location VARCHAR(255),
    date DATETIME,
    population NUMERIC,
    new_vaccinations NUMERIC,
    RollingPeopleVaccinated NUMERIC
);

-- Insert data into the table
INSERT INTO PercentPopulationVaccinated
SELECT 
    dea.continent, 
    dea.location, 
    dea.date, 
    dea.population, 
    CASE 
        WHEN vac.new_vaccinations REGEXP '^-?[0-9]+(\.[0-9]+)?$' THEN CAST(vac.new_vaccinations AS DECIMAL(10, 2))
        ELSE NULL -- or another default value
    END AS new_vaccinations,
    SUM(
        CASE 
            WHEN vac.new_vaccinations REGEXP '^-?[0-9]+(\.[0-9]+)?$' THEN CAST(vac.new_vaccinations AS DECIMAL(10, 2))
            ELSE 0
        END
    ) OVER (PARTITION BY dea.location ORDER BY dea.location, dea.date) AS RollingPeopleVaccinated
FROM 
    PortfolioProject.coviddeaths dea
JOIN 
    PortfolioProject.covidvaccinations vac
ON 
    dea.location = vac.location
    AND dea.date = vac.date;

-- Select data from the table
SELECT 
    *, 
    (RollingPeopleVaccinated / population) * 100
FROM 
    PercentPopulationVaccinated;



-- Creating View to store data for later visualizations
-- DROP TABLE IF EXISTS PercentPopulationVaccinatedView;
CREATE VIEW PercentPopulationVaccinatedView AS
SELECT 
    dea.continent, 
    dea.location, 
    dea.date, 
    dea.population, 
    vac.new_vaccinations,
    (
        SELECT SUM(CAST(vac_inner.new_vaccinations AS SIGNED))
        FROM PortfolioProject.covidvaccinations vac_inner
        WHERE dea.location = vac_inner.location
        AND dea.date = vac_inner.date
    ) AS RollingPeopleVaccinated
FROM 
    PortfolioProject.coviddeaths dea
JOIN 
    PortfolioProject.covidvaccinations vac ON dea.location = vac.location
                                           AND dea.date = vac.date
WHERE 
    dea.continent IS NOT NULL;

