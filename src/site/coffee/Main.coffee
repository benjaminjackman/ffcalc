Rules = {
  karalis: {
    #Total at the position for a team
    posCntTeam : {
      DEF:1
      K:1
      QB:2
      RB:3
      TE:1
      WR:4
    }
    flexCnt: 0

    totalPlayers:17
    #number of players that were kept
    keptCnt : 12+11
    teamCnt : 12
    #No defense / kicker
    startingCash : 183
    totalCash: () ->
      #total money left after keepers on each team -
      #200+194+65+126+184+152+164+147+146+150+121+177 - this.totalPlayers * this.teamCnt - this.keptCnt
      183*12

    #playersPerTeam = 15
    forceDefKToOne : true
  }

  schief: {
    #Total at the position for a team
    posCntTeam : {
      DEF:1
      K:1
      QB:1
      RB: 2
      TE: 1
      WR: 3
    }
    #RB/WR/TE flex
    flexPos: ["RB","WR","TE"]
    flexCnt: 1

    totalPlayers:17
    #number of players that were kept
    keptCnt : 0+1+3+3+1+2+1+3+3+3+3+2
    teamCnt : 12
    #No defense / kicker
    startingCash : 183
    totalCash: () ->
      #total money left after keepers on each team -
      200+194+65+126+184+152+164+147+146+150+121+177 - this.totalPlayers * this.teamCnt - this.keptCnt

    #playersPerTeam = 15
    forceDefKToOne : true
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
    player.kept = player.kept == "t"
  #  player.value = +player.value
  #  player.lvalue = +player.lvalue

  #Headers in the output table
  Headers = ["pos", "prk", "name", "team", "bye", "inj", "age", "exp", "pts", "nvalue", "p80", "kept"]



  #totalCash = 135+196+169+80+154+179+146+86+82+143+150+145
  keptCnt = 0

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
          return 0
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
          return 0
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
        input.value = lookup(name, team, pos)
      }
      [].forEach.call(document.querySelectorAll(".pncPlayerRow"), dop)
    """

    code

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
      #don't consider bench, these are the players that will start for some team in the league at this position
      useInTotals = not ((pos == "DEF" or pos == "K") and rules.forceDefKToOne)
      picks = _.first players, posCntLeague[pos]
      _.forEach picks, (p) -> if p.kept then keptCnt++
      picks = _.filter picks, (p) -> !p.kept

      pts = picks.map (p) -> p.pts
      #create a set of stats for each position
      posToStats[pos] = stats = {}
      stats.min = d3.min(pts)
      stats.max = d3.max(pts)
      stats.sum = d3.sum(pts)
      stats.avg = d3.mean(pts)
      stats.median = d3.median(pts)
      stats.diff = stats.max - stats.min
      #Add the total points at the position to the overall total points
      if useInTotals then totPnts += stats.sum
      #A players diff is equal to his pts minus the worst starter at his position
      _.forEach players, (p) -> p.diff = p.pts - stats.min
      #For each position compute the total of all the pickable players diffs,
      # these will be the points that people are competing in the draft over
      # these are the points that matter and what money should be spent on
      stats.totDiff = d3.sum(picks, (p)->p.diff)
      #record in the overall total diff as well
      if useInTotals then totDiff += stats.totDiff

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


  processPlayers(players)


#process(d3.csv.parse(fine2013), fineRules)
#process(d3.csv.parse(schief2013), schiefRules)
process(d3.csv.parse(karalis2014), Rules.karalis)
