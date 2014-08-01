Rules = {
  karalis: {
    #Total at the position for a team
    posCntTeam : {
      DEF:1
      K:1
      QB:1
      RB:2
      TE:1
      WR:3
    }

    #   #RB/WR/TE flex
    #   flexPos: ["RB","WR","TE"]
    #   flexCnt: 1
    

    totalPlayers:15
    #playersPerTeam = 15
    forceDefKToOne : true

    #No defense / kicker
    startingCash : 200
    teamCnt : 12
    #   forceDefKToOne : true

    calcKeeperCnt : 0
    calcKeeperValue : 0

    totalCash: () ->
      #total money left after keepers on each team -
      playersToDraft = @totalPlayers * @teamCnt - @calcKeeperCnt
      ret = @startingCash * @teamCnt - playersToDraft - @calcKeeperValue
      ret

  }
}


process = (players, rules) ->

  _.forEach players, (player) ->
    player.prk = +player.prk
    player.name = player.name.trim()
    player.bye = +player.bye
    player.age = +player.age
  #  player.exp = if player.exp == "R" then 0 else +player.exp
    player.pts = +player.pts
    player.kept = +player.kept
    if player.kept > 0
      rules.calcKeeperCnt += 1
      rules.calcKeeperValue += player.kept
  #  player.value = +player.value
  #  player.lvalue = +player.lvalue

  #Headers in the output table
  Headers = ["pos", "prk", "name", "team", "bye", "inj", "age", "exp", "pts", "nvalue", "p80", "kept"]

  playerToRow = (p) ->
    _.map Headers, (h) -> p[h]

  #pos,prk,name,team,bye,inj,age,exp,pts,value,lvalue,owner,bid,notes
  processPlayers = (players) ->
    #Total at each positon for the whole leage
    posCntLeague = {}
    for pos, cnt of rules.posCntTeam
      posCntLeague[pos] = Math.floor(cnt * rules.teamCnt)


    #add index to players, will be needed later to print return values in the same order
    players.forEach (p, i) -> p.index = i
    posToPlayers = _.groupBy players, (player) -> player.pos
    _.forEach posToPlayers,  (players, pos) ->
      posToPlayers[pos] = _.sortBy players, (p) -> -p.pts

    #Add in the flex to each of the positions counts
    #the flex is used by removing the top players from the WR/RB/TE
    # positions and then sorting the remaining
    # then taking to the flexCnt from different positions
    addFlex= () ->
      if rules.flexCnt > 0
        flexCnt = rules.flexCnt * rules.teamCnt
        ps = []
        for pos in rules.flexPos
          ps = ps.concat(_.drop posToPlayers[pos], posCntLeague[pos])

        ps = _.sortBy ps, (p) -> -p.pts

        ps = _.first ps, flexCnt

        _.forEach ps, (p) ->
          posCntLeague[p.pos] += 1

    console.log(posCntLeague)
    addFlex()
    console.log(posCntLeague)

    posToStats = {}
    totPnts = 0
    totDiff = 0
    _.forEach posToPlayers, (players, pos) ->
      useInTotals = not ((pos == "DEF" or pos == "K") and rules.forceDefKToOne)
      #don't consider bench, these are the players that will start for some team in the league at this position
      picks = _.first players, posCntLeague[pos]
      #filter out keepers from the pool of players to be picked at that position
      #if someone keeps too many players at a position this might cause some minor
      #misvaluation
      picks = _.filter picks, (p) -> p.kept == 0


      pts = picks.map (p) -> p.pts
      #create a set of stats for each position
      posToStats[pos] = posStats = {}
      posStats.min = d3.min(pts)
      posStats.max = d3.max(pts)
      posStats.sum = d3.sum(pts)
      posStats.avg = d3.mean(pts)
      posStats.median = d3.median(pts)
      posStats.diff = posStats.max - posStats.min
      #Add the total points at the position to the overall total points
      if useInTotals then totPnts += posStats.sum
      #A players diff is equal to his pts minus the worst starter at his position
      _.forEach players, (p) -> p.diff = p.pts - posStats.min
      #For each position compute the total of all the pickable players diffs,
      # these will be the points that people are competing in the draft over
      # these are the points that matter and what money should be spent on
      posStats.totDiff = d3.sum(picks, (p)->p.diff)
      #record in the overall total diff as well
      if useInTotals then totDiff += posStats.totDiff

    # therefore the value of each player is simply equal to his portion of the overall diff pool
    _.forEach players, (p) ->
      p.pct = p.diff / totDiff
      value = p.pct * rules.totalCash()
      p.nvalue = d3.round(value)
      p.p80 = d3.round(value * .8)

    espnCode = espnDump(players)
    $("#output").append("<textarea>#{espnCode}</textarea>")

    table = d3.select("#output").append("table")
    thead = table.append("thead").append("tr")
    thead.selectAll("td").data(Headers).enter().append("td").text((d)->d)
    tbody = table.append("tbody")
    tbody.selectAll("tr").data(players).enter().append("tr").selectAll("td").data((p)->playerToRow(p)).enter().append("td").text((d)->d)

  espnDump = (players) ->
    console.log("ESPN: ")
    ps = _.map players, (p) -> {name: p.name, team: p.team, pos: p.pos, prc: p.nvalue}
    code = """
      var players = #{JSON.stringify(ps)}
      var tc = function(t) {
        switch (t) {
          case "WSH":
            return "WAS"
          case  "JAC":
            return "JAX"
          default:
            return t
        }
      }

      function lookup(name, eteam, pos) {
        var team = tc(eteam)
        var xs = players.filter(function(p){return p.name === name && p.team === team})
        if (xs.length == 0) {
          console.error("FOUND NO MATCH:", name, team, pos)
          return null
        } else if (xs.length == 1) {
          console.log("FOUND EXACT MATCH:", name, team, pos, xs)
          var prc = xs[0].prc
          if (prc < -20) {
            return 1
          } else if (prc <= 0) {
            return 2
          } else if (prc <= 3) {
            return 3
          } else {
            return prc
          }
        } else {
          console.error("FOUND TOO MANY MATCHES:", name, team, pos, found)
          return null
        }
      }

      function dop(html) {
        var input = html.querySelector(".playertableData input")
        var name = html.querySelector(".playertablePlayerName a").text
        var txt = ""+html.querySelector(".playertablePlayerName").childNodes[1].textContent
        var split = /,\\s(\\S*)\\s(\\S*)/g.exec(txt)
        var team = split[1].toUpperCase()
        var pos = split[2].toUpperCase()

        //console.log(name,team,pos)
        var calc = lookup(name, team, pos)
        if (calc != null) input.value = calc
      }
      [].forEach.call(document.querySelectorAll(".pncPlayerRow"), dop)
    """

    code    


  processPlayers(players)


#process(d3.csv.parse(fine2013), fineRules)
#process(d3.csv.parse(schief2013), schiefRules)
process(d3.csv.parse(karalis2014), Rules.karalis)
