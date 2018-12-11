-module(population).

-export([go/0, go_print/0]).

go_print() ->
    io:format("~p~n", [go()]).

go() ->
    {ok, Content} = file:read_file("gpw_v4_basic_demographic_characteristics_rev10_atotpopbt_2010_cntm_1_deg.asc"),
    AllLines = string:tokens(binary_to_list(Content), "\r\n"),
    [NC,NR,XC,YC,CS,ND|RevLines] = AllLines,
    %% Lines needs to be reversed as they start from north and we are analysing from the south
    Lines = lists:reverse(RevLines),
    State = #{
      ncols => int(NC),
      nrows => int(NR),
      xstart => int(XC),
      ystart => int(YC),
      cellsize => round(flt(CS) * 1000) / 1000,
      nodata => str(ND)
     },
    Sums = sum_lines(State, Lines),
    Sum = sum_sums(Sums),
    Accs = acc_sums(Sums, Sum),
    #{sum => Sum, accs => Accs, sums => Sums}.

sum_lines(State, Lines) ->
    YStart = maps:get(ystart, State),
    CellSize = maps:get(cellsize, State),
    NoData = maps:get(nodata, State),
    {_YLast,Sums} = lists:foldl(fun(Line, {Y, Acc}) ->
					Sum = sum_line(Line, NoData),
					{Y + CellSize, [{Y, Sum}|Acc]}
				end,
				{YStart,[]},
				Lines),
    Sums.

sum_line(Line, NoData) ->
    Values = string:tokens(Line, " "),
    lists:foldl(fun(Str, Acc) when Str == NoData ->
			Acc;
		   (Str, Acc) ->
			case lists:member($., Str) of
			    true ->
				Acc + list_to_float(Str);
			    false ->
				Acc + list_to_integer(Str)
			end
		end,
		0,
		Values).

acc_sums(Sums, Sum) ->
    lists:reverse(lists:foldl(fun({L,S}, Accs = [{_,Acc,AccPercent} | _]) ->
				      NewAcc = Acc + S,
				      NewAccPercent = AccPercent + 100*S/Sum,
				      [{L,NewAcc,NewAccPercent} | Accs]
			      end,
			      [{dummy, 0.0, 0.0}],
			      Sums)).

sum_sums(Sums) ->
    lists:foldl(fun({_,S}, Sum) ->
			Sum + S
		end,
		0,
		Sums).

int(Field) ->
    list_to_integer(str(Field)).

flt(Field) ->
    list_to_float(str(Field)).

str(Field) ->		  
    [_,Str] = string:tokens(Field, " "),
    Str.
