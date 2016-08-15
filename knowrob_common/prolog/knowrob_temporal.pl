/** <module> Predicates for temporal reasoning in KnowRob

  Copyright (C) 2016 Daniel Beßler
  All rights reserved.

  Redistribution and use in source and binary forms, with or without
  modification, are permitted provided that the following conditions are met:
      * Redistributions of source code must retain the above copyright
        notice, this list of conditions and the following disclaimer.
      * Redistributions in binary form must reproduce the above copyright
        notice, this list of conditions and the following disclaimer in the
        documentation and/or other materials provided with the distribution.
      * Neither the name of the <organization> nor the
        names of its contributors may be used to endorse or promote products
        derived from this software without specific prior written permission.

  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
  DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
  DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
  ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

@author Daniel Beßler
@license BSD
*/

:- module(knowrob_temporal,
    [
      holds/1,
      holds/2,
      holds/3,
      holds/4,
      occurs/1,
      occurs/2,
      interval/2,
      interval_start/2,
      interval_end/2,
      interval_before/2,
      interval_after/2,
      interval_meets/2,
      interval_starts/2,
      interval_finishes/2,
      interval_overlaps/2,
      interval_during/2,
      fluent_has/3,
      fluent_has/4,
      fluent_assert/3,
      fluent_assert/4,
      fluent_assert_end/3,
      fluent_assert_end/2
    ]).

:- use_module(library('semweb/rdf_db')).
:- use_module(library('semweb/rdfs')).
:- use_module(library('owl')).
:- use_module(library('rdfs_computable')).
:- use_module(library('knowrob_owl')).

% define predicates as rdf_meta predicates
% (i.e. rdf namespaces are automatically expanded)
:- rdf_meta holds(t),
            holds(t,?),
            holds(r,r,t),
            holds(r,r,t,?),
            occurs(?),
            occurs(?,?),
            interval(?,?),
            interval_start(?,?),
            interval_end(?,?),
            interval_before(?,?),
            interval_after(?,?),
            interval_meets(?,?),
            interval_starts(?,?),
            interval_finishes(?,?),
            interval_overlaps(?,?),
            interval_during(?,?),
            fluent_has(r,r,t,?),
            fluent_has(r,r,t),
            fluent_assert(r,r,t),
            fluent_assert(r,r,t,r),
            fluent_assert_end(r,r,r),
            fluent_assert_end(r,r).

% define holds as meta-predicate and allow the definitions
% to be in different source files
:- meta_predicate holds(0, ?, ?),
                  occurs(0, ?, ?).
:- multifile holds/2,
             occurs/2.

%% holds(+Term, ?T)
%% holds(+Term)
%
% True iff @Term holds during @T. Where @T is a TimeInterval or TimePoint individual,
% a number or a list of two numbers representing a time interval.
%
% @param Term Must be of the form: "PROPERTY(SUBJECT, OBJECT)".
%             For example: `Term = knowrob:insideOf(example:'DinnerPlate_fdigh245', example:'Drawer_bsdgwe8trg')`.
% @param T Can be TimeInterval or TimePoint individual, a number or a list of two numbers
%          representing a time interval.
%
holds(Term) :-
  current_time(T),
  holds(Term,T).

holds(Term, I) :-
  var(Term),
  holds(S, P, O, I),
  Term =.. [':', P, (S,O)].

holds(Term, I) :-
  nonvar(Term),
  (  Term =.. [':', Namespace, Tail]
  -> (
     Tail =.. [P,S,O],
     % unpack namespace
     rdf_current_ns(Namespace, NamespaceUri),
     atom_concat(NamespaceUri, P, PropertyUri),
     holds(S, PropertyUri, O, I)
  ) ; (
     Term =.. [P,S,O],
     holds(S, P, O, I)
  )), !.

holds(S, P, O) :-
  current_time(T),
  holds(S, P, O, [T,T]).

holds(S, P, O, I) :-
  ( atom(S) ; var(S) ),
  (  atom(P)
  -> rdf_triple(P, S, O)
  ;  owl_has(S,P,O)
  ),
  (  var(I)
  -> I = [0.0]
  ;  true
  ).
  
holds(S, P, O, I) :-
  ( atom(S) ; var(S) ),
  fluent_has(S, P, O, TimeInterval),
  time_term(TimeInterval, Interval),
  (  var(I)
  -> I = Interval
  ;  interval_during(I, Interval)
  ).

%% occurs(?Evt) is nondet.
%% occurs(?Evt,?T) is nondet.
%
% True iff @Evt occurs during @T. Where @T is a TimeInterval or TimePoint individual,
% a number or a list of two numbers representing a time interval.
%
% @param Evt Identifier of the event or a term of the form $Type($Instance)
% @param T   Timepoint or time interval
% 
occurs(Evt) :-
  current_time(T),
  occurs(Evt, T).

% Read event instance from RDF triple store
occurs(EvtDescr, I) :-
  rdfs_individual_of(Evt, knowrob:'Event'),
  entity(Evt, EvtDescr),
  interval(Evt, EvtI),
  (  var(I)
  -> I = EvtI
  ;  interval_during(I, EvtI) ).

%% NOTE(daniel): Define computable occurs in external files like this:
%% knowrob_temporal:occurs(my_event, Descr, [T0,T1]) :-
%%    occurs_my_event(Descr,[T0,T1]).



% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % %
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % %
% methods for asserting fluent relations


fluent_assert(S, P, O) :-
  current_time(Now),
  fluent_assert(S, P, O, [Now]), !.

fluent_assert(S, P, O, [Begin,End]) :-
  number(Begin), number(End),
  create_interval([Begin,End], I),
  fluent_assert(S, P, O, I), !.

fluent_assert(S, P, O, [Begin]) :-
  number(Begin),
  create_timepoint(Begin, IntervalStart),
  rdf_instance_from_class(knowrob:'TimeInterval', I),
  rdf_assert(I, knowrob:'startTime', IntervalStart),
  fluent_assert(S, P, O, I), !.

fluent_assert(S, P, O, TimeInst) :-
  atom(TimeInst),
  rdfs_individual_of(TimeInst, knowrob:'Timepoint'),
  time_term(TimeInst, Time),
  fluent_assert(S, P, O, [Time]), !.

fluent_assert(S, P, O, Time) :-
  number(Time),
  fluent_assert(S, P, O, [Time]), !.

fluent_assert(S, P, O, I) :-
  atom(I),
  rdfs_individual_of(I, knowrob:'TimeInterval'),
  % Create temporal parts
  rdf_instance_from_class(knowrob:'TemporalPart', SubjectPart),
  rdf_assert(SubjectPart, knowrob:'temporalPartOf', S),
  rdf_assert(SubjectPart, knowrob:'temporalProperty', P),
  rdf_assert(SubjectPart, knowrob:'temporalExtend', I),
  (  rdf_has(P, rdf:type, owl:'ObjectProperty')
  ->  (
      rdf_instance_from_class(knowrob:'TemporalPart', ObjectPart),
      rdf_assert(ObjectPart, knowrob:'temporalPartOf', O),
      rdf_assert(ObjectPart, knowrob:'temporalExtend', I),
      rdf_assert(SubjectPart, P, ObjectPart)
      )
  ;   rdf_assert(SubjectPart, P, O)
  ), !.

fluent_assert_end(S, P) :-
  current_time(Now),
  fluent_assert_end(S, P, Now), !.

fluent_assert_end(S, P, Time) :-
  number(Time),
  forall((
    rdf_has(SubjectPart, knowrob:'temporalPartOf', S),
    rdf_has(SubjectPart, P, _)
  ), (
    rdf_has(SubjectPart, knowrob:'temporalExtend', I),
    not( rdf_has(I, knowrob:'endTime', _) ),
    create_timepoint(Time, IntervalEnd),
    rdf_assert(I, knowrob:'endTime', IntervalEnd)
  )).

fluent_property(TemporalPart, PropertyIri) :-
  rdf_has(TemporalPart, knowrob:temporalProperty, PropertyIri).

%% fluent_has(?Subject, ?Predicate, ?Object, ?Interval)
%
% True if this relation is specified via knowrob:TemporalPart
% or can be deduced using OWL inference rules.
% 
fluent_has(S, P, O) :- fluent_has(S, P, O, _).

fluent_has(S, P, O, I) :-
  owl_has(S, knowrob:hasTemporalPart, TemporalPart),
  fluent_has(TemporalPart, P, O, I).

fluent_has(S, P, O, I) :-
  nonvar(S),
  rdfs_individual_of(S, knowrob:'TemporalPart'),
  rdf_has(S, knowrob:temporalExtend, I),
  rdf_has(S, knowrob:temporalProperty, P),
  rdf_has(S, P, S_O),
  (( rdfs_individual_of(S_O, knowrob:'TemporalPart') )
  -> once(owl_has(S_O, knowrob:temporalPartOf, O))
  ;  O = S_O ).

% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % %
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % %
% Allen's interval algebra

%% interval(I,[ST,ET]) is semidet.
%
% The interval of I
%
% @param I Time point, interval or temporally extended entity
% @param [ST,ET] Start and end time of the interval
% 
interval([T0,T1], [T0,T1]).
interval([T0], [T0]).
interval(Time, [Time,Time]) :- number(Time).
interval(I, Interval) :-
  atom(I),
  rdf_has(I, knowrob:'temporalExtend', Ext),
  interval(Ext, Interval).
interval(TimePoint, [Time,Time]) :-
  atom(TimePoint),
  rdfs_individual_of(TimePoint, knowrob:'TimePoint'),
  time_term(TimePoint, Time).
interval(I, Interval) :-
  atom(I),
  rdf_has(I, knowrob:'startTime', T0),
  time_term(T0, T0_val),
  (  rdf_has(I, knowrob:'endTime', T1)
  -> (time_term(T1, T1_val), Interval=[T0_val,T1_val])
  ;  Interval=[T0_val] ).

%% interval_start(I,End) is semidet.
%
% The start time of I 
%
% @param I Time point, interval or temporally extended entity
% 
interval_start(I, Start) :- (interval(I, [Start,_]) ; interval(I, [Start])), !.
%% interval_end(I,End) is semidet.
%
% The end time of I 
%
% @param I Time point, interval or temporally extended entity
% 
interval_end(I, End)     :- interval(I, [_,End]), !.

%% interval_before(I0,I1) is semidet.
%
%  Interval I0 takes place before I1
%
% @param I0 Time point, interval or temporally extended entity
% @param I1 Time point, interval or temporally extended entity
% 
interval_before(I0, I1) :-
  interval(I0, [_,End0]),
  ( interval(I1, [Begin1,_]);
    interval(I1, [Begin1]) ),
  (End0 < Begin1), !.

%% interval_after(I0,I1) is semidet.
%
% Interval I0 takes place after I1
%
% @param I0 Time point, interval or temporally extended entity
% @param I1 Time point, interval or temporally extended entity
% 
interval_after(I0, I1) :-
  interval(I1, [_,End1]),
  ( interval(I0, [Begin0,_]);
    interval(I0, [Begin0]) ),
  (Begin0 > End1), !.

%% interval_meets(I0,I1) is semidet.
%
% Intervals I0 and I1 meet, i.e. the end time of I0 is equal to the start time of I1
%
% @param I0 Time point, interval or temporally extended entity
% @param I1 Time point, interval or temporally extended entity
% 
interval_meets(I0, I1) :-
  interval(I0, [_,Time]),
  ( interval(I1, [Time,_]);
    interval(I1, [Time]) ), !.

%% interval_starts(I0,I1) is semidet.
%
% Interval I0 starts interval I1, i.e. both have the same start time, but I0 finishes earlier
%
% @param I0 Time point, interval or temporally extended entity
% @param I1 Time point, interval or temporally extended entity
% 
interval_starts(I0, I1) :-
  interval(I0, [T_start,End0]),
  (( interval(I1, [T_start,End1]),
     (End0 < End1) ) ;
     interval(I1, [T_start]) ), !.

%% interval_finishes(I0,I1) is semidet.
%
% Interval I0 finishes interval I1, i.e. both have the same end time, but I0 starts later
%
% @param I0 Time point, interval or temporally extended entity
% @param I1 Time point, interval or temporally extended entity
% 
interval_finishes(I0, I1) :-
  interval(I0, [Begin0,T_end]),
  interval(I1, [Begin1,T_end]),
  (Begin0 > Begin1), !.

%% interval_overlaps(I0,I1) is semidet.
%
% Interval I0  overlaps temporally with I1
%
% @param I0 Time point, interval or temporally extended entity
% @param I1 Time point, interval or temporally extended entity
% 
interval_overlaps(I0, I1) :-
  ( interval(I0, [Begin0,End0]);
    interval(I0, [Begin0]) ),
  (( interval(I1, [Begin1,End1]),
     ( nonvar(End0), (End0 < End1) ));   % ends before the end of
     interval(I1, [Begin1]) ),
  (var(End0) ; (End0 > Begin1)),         % ends after the start of
  (Begin0 < Begin1),!.                   % begins before the start of

%% interval_during(I0,I1) is semidet.
%
% Interval I0 is inside interval I1, i.e. it starts later and finishes earlier than I1.
%
% @param I0 Time point, interval or temporally extended entity
% @param I1 Time point, interval or temporally extended entity
% 
interval_during(Time0, I1) :-
  number(Time0),
  (( interval(I1, [Begin1,End1]),
     (Time0 < End1) ) ;
     interval(I1, [Begin1]) ),
  (Begin1 < Time0), !.
interval_during(I0, I1) :-
  ( interval(I0, [Begin0,End0]) ;
    interval(I0, [Begin0]) ),
  (( nonvar(End0),
     interval(I1, [Begin1,End1]),
     (End0 =< End1) ) ;
     interval(I1, [Begin1]) ),
  (Begin1 =< Begin0), !.

