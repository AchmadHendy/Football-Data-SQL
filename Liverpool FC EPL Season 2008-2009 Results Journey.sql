--Select Data from Linked Servers (SQLLite)
Select *
from openquery(SQLLITE, 'select * from Team')

Select *
from openquery(SQLLITE, 'select * from Match')

--Create Table and Insert data from table in Linked Servers
Select *
into Team
from openquery(SQLLITE, 'select * from Team')

Select *
into EPLMatch
from openquery(SQLLITE, 'select * from Match')
Where country_id = 1729

--Match Winner by api id
Select date, home_team_goal, away_team_goal, IIF(home_team_goal>away_team_goal, home_team_api_id, iIF(home_team_goal = away_team_goal, '', away_team_api_id)) as Winner
From EPLMatch
Where Season = '2008/2009'

--Match Loser by api_id
Select date, home_team_goal, away_team_goal, IIF(home_team_goal>away_team_goal, away_team_api_id, iIF(home_team_goal = away_team_goal, '', home_team_api_id)) as Loser
From EPLMatch
Where Season = '2008/2009'

--Add Winner Column
Alter Table EPLMatch
Add Winner float

Update EPLMatch
Set Winner = IIF(home_team_goal>away_team_goal, home_team_api_id, iIF(home_team_goal = away_team_goal, '', away_team_api_id))

--Add Loser Column
Alter Table EPLMatch
Add Loser float

Update EPLMatch
Set Loser = IIF(home_team_goal>away_team_goal, away_team_api_id, iIF(home_team_goal = away_team_goal, '', home_team_api_id))

--Winning Count
SELECT TeamLongName, COUNT(TeamLongName) AS TotalWon
FROM EPLMatch
JOIN Team
	ON EPLMatch.Winner = Team.team_api_id
Where season = '2008/2009'
Group By TeamLongName, team_api_id
Order By Count(TeamLongName) desc

--Create Winning Count TempTable
Drop Table if exists #WinningCount
Create Table #WinningCount
(
Team varchar(100),
TotalWon int,
)

Insert Into #WinningCount
SELECT TeamLongName, COUNT(TeamLongName) AS TotalWon
FROM EPLMatch
JOIN Team
	ON EPLMatch.Winner = Team.team_api_id
Where season = '2008/2009'
Group By TeamLongName, team_api_id
Order By Count(TeamLongName) desc

Select *
From #WinningCount

--Losing Count
SELECT TeamLongName, COUNT(TeamLongName) AS TotalLost
FROM EPLMatch
JOIN Team
	ON EPLMatch.Loser = Team.team_api_id
Where season = '2008/2009'
Group By TeamLongName, team_api_id
Order By Count(TeamLongName) desc

--Create Losing Count TempTable
Drop Table if exists #LosingCount
Create Table #LosingCount(
Team varchar(100),
TotalLost int,
)

Insert Into #LosingCount
SELECT TeamLongName, COUNT(TeamLongName) AS TotalLost
FROM EPLMatch
JOIN Team
	ON EPLMatch.Loser = Team.team_api_id
Where season = '2008/2009'
Group By TeamLongName, team_api_id
Order By Count(TeamLongName) desc

Select *
From #LosingCount

--Create Leagues Season Result TempTable
Select a.Team, TotalWon, TotalLost
From #WinningCount as a
JOIN #LosingCount as b
	ON a.Team = b.Team
Order By TotalWon desc

Drop Table if exists #LeagueSeasonResult
Create Table #LeagueSeasonResult
(
Team varchar(100),
TotalWon int,
TotalDraw int,
TotalLost int,
)

Insert Into #LeagueSeasonResult
Select a.Team, TotalWon, 38-(TotalWon + TotalLost), TotalLost
From #WinningCount as a
JOIN #LosingCount as b
	ON a.Team = b.Team

With CTE_LeagueSeasonResult as (
Select *, ((TotalWon * 3) + (TotalDraw *1) + (TotalLost * 0)) as Points 
From #LeagueSeasonResult
)

Select ROW_NUMBER() OVER (ORDER BY Points desc) as Rank, *
From CTE_LeagueSeasonResult

--Season Journey
With TotalPoints as (
SELECT season, Convert(date,date) as Date, Winner, 
CASE
	WHEN Winner = 8650 THEN 3
	WHEN Winner = 0 THEN 1
	ELSE 0
END AS Points
FROM EPLMatch
Where home_team_api_id = 8650 AND season = '2008/2009' OR away_team_api_id = 8650 AND season = '2008/2009'
)

Select season, Date, COUNT(Date) OVER (Partition By season Order By Date) as Match ,Points, SUM(Convert(int, Points)) OVER (Partition By season Order By date) as CalculatedPoint,
CASE
	WHEN Points = '3' THEN 'Win'
	WHEN Points = '1' THEN 'Draw'
	ELSE 'Lose'
END AS Result
From TotalPoints
