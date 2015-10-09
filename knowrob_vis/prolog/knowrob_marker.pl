

:- module(knowrob_marker,
    [
      marker_publish/0,
      
      marker/2,
      marker_update/0,
      marker_update/1,
      marker_update/2,
      marker_remove/1,
      
      marker_properties/2,
      marker_type/2,
      marker_scale/2,
      marker_mesh_resource/2,
      marker_pose/2,
      marker_translation/2,
      marker_text/2,
      marker_color/2,
      marker_highlight/2
    ]).
    
:- use_module(library('semweb/rdfs')).
:- use_module(library('semweb/rdf_db')).
:- use_module(library('rdfs_computable')).
:- use_module(library('jpl')).

:- rdf_meta marker(t,?),
            marker_update(t),
            marker_update(t,r),
            marker_remove(t),
            marker_type(t,?),
            marker_scale(t,?),
            marker_color(t,?),
            marker_mesh_resource(t,?),
            marker_pose(t,?),
            marker_translation(t,?),
            marker_text(t,?),
            marker_properties(t,?).

trajectory_sample(Frame, T, T_end, Interval, X) :-
  atom(T), time_term(T, T_Term), time_term(T_end, T_end_Term),
  trajectory_sample(Frame, T_Term, T_end_Term, Interval, X) .

trajectory_sample(Frame, T, T_end, Interval, [(Translation,Orientation,T)|Rest]) :-
  number(T), number(T_end),
  T =< T_end, T_next is T + Interval,
  object_lookup_transform(Frame, T, (Translation,Orientation)),
  trajectory_sample(Frame, T_next, T_end, Interval, Rest).

trajectory_sample(Frame, T, T_end, _, [(Translation,Orientation,T)]) :-
  number(T), number(T_end),
  T >= T_end, object_lookup_transform(Frame, T_end, (Translation,Orientation)).


object_has_visual(Identifier) :-
  not(owl_individual_of(Identifier, srdl2comp:'UrdfJoint')),
  not(owl_individual_of(Identifier, knowrob:'Agent-Generic')),
  not(owl_individual_of(Identifier, knowrob:'RoomInAConstruction')),
  not(rdf_has(Identifier, knowrob:'hasVisual', literal(type(_,false)))).

object_children(Parent, Children) :-
  findall(Child, (
    rdf_reachable(Part, knowrob:describedInMap, Parent),
    (
      rdf_reachable(Part, knowrob:'properPhysicalParts', Child);
      rdf_reachable(Part, srdl2comp:'subComponent', Child);
      rdf_reachable(Part, srdl2comp:'successorInKinematicChain', Child)
    ),
    not(Child = Parent)
  ), ChildrenList),
  list_to_set(ChildrenList, Children).

object_links(Identifier, Links) :-
  findall(Link, (
    owl_has(Identifier, srdl2comp:'subComponent', Component),
    owl_has(Component, srdl2comp:'baseLinkOfComposition', BaseLink),
    rdf_reachable(BaseLink, srdl2comp:'successorInKinematicChain', Link),
    owl_individual_of(Link, srdl2comp:'UrdfLink')
  ), LinksList),
  list_to_set(LinksList, Links).

succeeding_links(Link0, Links) :-
  findall(Link1, (
    rdf_has(Link0, srdl2comp:'successorInKinematicChain', Joint),
    rdf_has(Joint, srdl2comp:'successorInKinematicChain', Link1)
  ), Links).

object_frame(Identifier, UrdfName) :-
  rdf_has(Identifier, srdl2comp:'urdfName', literal(Tf)),
  atomic_list_concat(['/', Tf], UrdfName).

object_frame(UrdfName, UrdfName).

object_lookup_transform(Identifier, T, (Translation,Orientation)) :-
  object_pose_at_time(Identifier, T, Translation, Orientation).

% TODO: look at object pose at time
object_lookup_transform(Identifier, T, (Translation,Orientation)) :-
  object_lookup_transform(Identifier, '/map', T, (Translation,Orientation)).

object_lookup_transform(Identifier, TargetFrame, T, (Translation,Orientation)) :-
  object_frame(Identifier, TfFrame),
  not( atom_prefix(TfFrame, 'http') ),
  mng_lookup_transform(TargetFrame, TfFrame, T, Pose),
  matrix_rotation(Pose, Orientation),
  matrix_translation(Pose, Translation).


% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % %
%
% Marker constants
%

marker_prop_type(arrow,0).
marker_prop_type(cube,1).
marker_prop_type(sphere,2).
marker_prop_type(cylinder,3).
marker_prop_type(line_strip,4).
marker_prop_type(line_list,5).
marker_prop_type(cube_list,6).
marker_prop_type(sphere_list,7).
marker_prop_type(points,8).
marker_prop_type(text_view_facing,9).
marker_prop_type(mesh_resource,10).
marker_prop_type(triangle_list,11).


% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % %
%
% ROS node for marker visualization
%

marker_visualisation :-
  marker_visualisation(_).
  
marker_visualisation(MarkerVis) :-
  (\+ current_predicate(v_marker_vis, _)),
  jpl_call('org.knowrob.vis.MarkerPublisher', get, [], MarkerVis),
  jpl_list_to_array(['org.knowrob.vis.MarkerPublisher'], Arr),
  jpl_call('org.knowrob.utils.ros.RosUtilities', runRosjavaNode, [MarkerVis, Arr], _),
  assert(v_marker_vis(MarkerVis)),!.

marker_visualisation(MarkerVis) :-
  current_predicate(v_marker_vis, _),
  v_marker_vis(MarkerVis).


marker_publish :-
  marker_visualisation(MarkerVis),
  jpl_call(MarkerVis, 'publishMarker', [], _).


% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % %
%
% Marker factory
%


marker_create(MarkerTerm, MarkerObject, Parent) :-
  compound(MarkerTerm),
  % Ensures that there are no unbound variables in compound term
  numbervars(MarkerTerm,0,0),
  term_to_atom(MarkerTerm, MarkerAtom),
  jpl_call(Parent, 'createMarker', [MarkerAtom], MarkerObject),
  not(MarkerObject = @(null)),
  assert( v_marker_object(MarkerTerm, MarkerObject) ).


marker_create_n(_, _, 0, []).
marker_create_n(Prefix, Parent, Count, [X|Xs]) :-
  Count > 0,
  atom_concat(Prefix, Count, MarkerName),
  jpl_call(Parent, 'createMarker', [MarkerName], X),
  Count_next is Count - 1,
  marker_create_n(Prefix, Parent, Count_next, Xs).


marker_object(Term,Object) :-
  current_predicate(v_marker_object,_),
  v_marker_object(Term,Object).


marker_remove(all) :-
  marker_object(Term, _),
  marker_remove(Term).

marker_remove(trajectories) :-
  forall(
    marker_object(trajectory(Link), _),
    marker_remove(trajectory(Link))
  ).

marker_remove(Term) :-
  compound(Term),
  marker_visualisation(MarkerVis),
  term_to_atom(Term, Atom),
  jpl_call(MarkerVis, 'eraseMarker', [Atom], _),
  v_marker_object(Term, MarkerObject),
  retract( v_marker_object(Term, _) ),
  
  jpl_call(MarkerObject, 'getChildren', [], ChildrenArray),
  jpl_array_to_list(ChildrenArray,Children),
  forall( member(ChildObject,Children), ignore((
    v_marker_object(ChildTerm, ChildObject),
    marker_remove(ChildTerm)
  ))).


marker(MarkerTerm, MarkerObject) :-
  marker_visualisation(MarkerVis),
  marker(MarkerTerm, MarkerObject, MarkerVis).

marker(MarkerTerm, MarkerObject, _) :-
  marker_object(MarkerTerm, MarkerObject).

marker(cube(Name), MarkerObject, Parent) :-
  marker_primitive(cube, cube(Name), MarkerObject, Parent).

marker(sphere(Name), MarkerObject, Parent) :-
  marker_primitive(sphere, sphere(Name), MarkerObject, Parent).

marker(arrow(Name), MarkerObject, Parent) :-
  marker_primitive(arrow, arrow(Name), MarkerObject, Parent).

marker(cylinder(Name), MarkerObject, Parent) :-
  marker_primitive(cylinder, cylinder(Name), MarkerObject, Parent).

marker(cylinder_tf(From,To), MarkerObject, Parent) :-
  marker_primitive(cylinder, cylinder_tf(From,To), MarkerObject, Parent).

marker(link(Link), MarkerObject, Parent) :-
  marker_primitive(arrow, link(Link), MarkerObject, Parent).

marker(path(Link,Name,Count), MarkerObject, Parent) :-
  marker_primitive(arrow, Name, MarkerObject, Parent),
  marker_color(MarkerObject, [1.0,1.0,0.0,1.0]),
  marker_has_visual(MarkerObject, false),
  marker_create_n(Link, MarkerObject, Count, _).

marker(trajectory(Link), MarkerObject, Parent) :-
  marker(trajectory(Link,8), MarkerObject, Parent).

marker(trajectory(Link,Count), MarkerObject, Parent) :-
  marker(path(Link,trajectory(Link),Count), MarkerObject, Parent).

marker(trail(Link), MarkerObject, Parent) :-
  marker(trail(Link,8), MarkerObject, Parent).

marker(trail(Link,Count), MarkerObject, Parent) :-
  marker(path(Link,trail(Link),Count), MarkerObject, Parent),
  AlphaStep is 1.0 / Count,
  Alpha is 1.0,
  jpl_call(MarkerObject, 'getChildren', [], ChildrenArray),
  jpl_array_to_list(ChildrenArray,Children),
  marker(trail(Link,Alpha,AlphaStep,Children), MarkerObject, Parent).

marker(trail(_,_,_,[]), _, _).

marker(trail(Link,Alpha,AlphaStep,[Child|Rest]), _, _) :-
  marker_alpha(Child, Alpha),
  Alpha_next is Alpha - AlphaStep,
  marker(trail(Link,Alpha_next,AlphaStep,Rest), _, _).

marker(average_trajectory(Link), MarkerObject, Parent) :-
  marker_primitive(arrow, average_trajectory(Link), MarkerObject, Parent),
  marker_has_visual(MarkerObject, false).

marker(pointer(From,To), MarkerObject, Parent) :-
  marker_primitive(arrow, pointer(From,To), MarkerObject, Parent).

marker(mesh(Name), MarkerObject, Parent) :-
  marker_create(mesh(Name), MarkerObject, Parent),
  marker_type(MarkerObject, mesh_resource),
  marker_color(MarkerObject, [0.0,0.0,0.0,0.0]),
  marker_scale(MarkerObject, [1.0,1.0,1.0]).

marker(mesh(Name,MeshFile), MarkerObject, Parent) :-
  marker(mesh(Name), MarkerObject, Parent),
  marker_mesh_resource(MarkerObject, MeshFile).

marker(object(Identifier), MarkerObject, Parent) :-
  marker_primitive(cube, object(Identifier), MarkerObject, Parent),
  marker_initialize_object(Identifier, MarkerObject).

marker(object_with_children(Identifier), MarkerObject, Parent) :-
  marker_primitive(cube, object_with_children(Identifier), MarkerObject, Parent),
  marker_initialize_object(Identifier, MarkerObject),
  object_children(Identifier,Children),
  forall(
    member( Child,Children ), ignore((
      marker( object_with_children(Child), _, MarkerObject )
    ))
  ).

marker(agent(Identifier), MarkerObject, Parent) :-
  marker(kinematic_chain(Identifier,agent(Identifier)), MarkerObject, Parent).

marker(kinematic_chain(Identifier), MarkerObject, Parent) :-
  marker(kinematic_chain(Identifier,kinematic_chain(Identifier)), MarkerObject, Parent).

marker(kinematic_chain(Identifier,Name), MarkerObject, Parent) :-
  marker_primitive(arrow, Name, MarkerObject, Parent),
  marker_initialize_object(Identifier,MarkerObject),
  
  object_links(Identifier, Links),
  forall( member( Link,Links ), ignore((
    object_has_visual( Link ),
    marker( object(Link), _, MarkerObject )
  ))).

marker(stickman(Identifier), MarkerObject, Parent) :-
  marker_primitive(sphere, stickman(Identifier), MarkerObject, Parent),
  marker_initialize_object(Identifier,MarkerObject),
  marker_color(MarkerObject, [1.0,1.0,0.0,1.0]),
  
  object_links(Identifier, Links),
  forall( member( Link,Links ), ignore((
    marker( object(Link), LinkMarker, MarkerObject ),
    marker_type(LinkMarker, sphere),
    
    succeeding_links(Link, SucceedingLinks),
    forall(
      member( SucceedingLink,SucceedingLinks ),
      once( marker( cylinder_tf(Link,SucceedingLink), _, MarkerObject) )
    )
  ))).

marker(text(Id), MarkerObject, Parent) :-
  marker_primitive(text_view_facing, text(Id), MarkerObject, Parent),
  marker_color(MarkerObject, [0.6,0.9,0.6,1.0]),
  marker_scale(MarkerObject, [1.0,1.0,1.0]).

marker(text(Id,Text), MarkerObject, Parent) :-
  marker(text(Id), MarkerObject, Parent),
  marker_text(MarkerObject, Text).


marker_initialize_object(Identifier,MarkerObject) :-
  (  object_has_visual(Identifier)
  -> marker_has_visual(MarkerObject,true)
  ;  marker_has_visual(MarkerObject,false)
  ),
  ignore((
    get_model_path(Identifier, Path),
    marker_type(MarkerObject, mesh_resource),
    marker_mesh_resource(MarkerObject, Path),
    marker_color(MarkerObject, [0.0,0.0,0.0,0.0]),
    marker_scale(MarkerObject, [1.0,1.0,1.0])
  )),
  ignore(( object_dimensions(Identifier, X, Y, Z), marker_scale(MarkerObject, [X, Y, Z]) )),
  ignore((
    object_color(Identifier, Color),
    parse_vector(Color, ColorList),
    marker_color(MarkerObject, ColorList)
  )).


marker_primitive(Type, MarkerTerm, MarkerObject, Parent) :-
  marker_create(MarkerTerm, MarkerObject, Parent),
  marker_type(MarkerObject, Type),
  marker_color(MarkerObject, [0.6,0.6,0.6,1.0]),
  marker_scale(MarkerObject, [0.05,0.05,0.05]).


% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % %
%
% Updating marker
%

marker_update :-
  get_timepoint(T),
  marker_update(T).

marker_update(Identifier) :-
  compound(Identifier),
  get_timepoint(T),
  marker_update(Identifier,T).

marker_update(T) :-
  ( atom(T) ; number(T) ),
  forall(
    marker(Identifier, _),
    ignore(marker_update(Identifier, T))
  ).

marker_update(Identifier, T) :-
  atom(T), time_term(T, T_Term),
  marker_update(Identifier, T_Term).

marker_update(Identifier, dt(T0,DT)) :-
  atom(T0), time_term(T0, T0_Term),
  marker_update(Identifier, dt(T0_Term,DT)).

marker_update(Identifier, interval(T0,T1)) :-
  atom(T0), time_term(T0, T0_Term),
  atom(T1), time_term(T1, T1_Term),
  marker_update(Identifier, interval(T0_Term,T1_Term)).

marker_update(Identifier, T) :-
  number(T),
  marker_update(Identifier, time(T,T)).

marker_update(Identifier, dt(T0,DT)) :-
  number(T0), number(DT),
  marker_update(Identifier, time(T0,dt(T0,DT))).

marker_update(Identifier, interval(T0,T1)) :-
  number(T0), number(T1),
  marker_update(Identifier, time(T0,interval(T0,T1))).

marker_update(Identifier, time(T,Arg)) :-
  number(T),
  T_float is float(T),
  marker(Identifier, MarkerObject),
  marker_timestamp(MarkerObject, Last_T),
  % Only update once for given timestamp
  ( Last_T is T_float ; once((
    marker_timestamp(MarkerObject, T_float),
    marker_update(Identifier, MarkerObject, Arg)
  ))).

marker_update(object_with_children(Identifier), MarkerObject, T) :-
  marker_update(object(Identifier), MarkerObject, T).

marker_update(object(Identifier), MarkerObject, T) :-
  ignore((
    object_lookup_transform(Identifier,T,(Translation,Orientation)),
    marker_pose(MarkerObject,Translation,Orientation)
  )),
  jpl_call(MarkerObject, 'getChildren', [], ChildrenArray),
  jpl_array_to_list(ChildrenArray,Children),
  forall(member(ChildObject,Children), once((
    marker_object(ChildTerm, ChildObject),
    marker_update(ChildTerm, ChildObject, T),
    marker_timestamp(MarkerObject, T)
  ))).

marker_update(link(Link), MarkerObject, T) :-
  object_lookup_transform(Link,T,(Translation,Orientation)),
  marker_pose(MarkerObject,Translation,Orientation).

marker_update(pointer(From,To), MarkerObject, T) :-
  mng_lookup_transform(From, To, T, Pose),
  matrix_rotation(Pose, Orientation),
  matrix_translation(Pose, Translation),
  marker_pose(MarkerObject,Translation,Orientation).

marker_update(cylinder_tf(From,To), MarkerObject, T) :-
  object_frame(From, FromFrame),
  object_frame(To, ToFrame),
  mng_lookup_transform('/map', FromFrame, T, Pose0),
  mng_lookup_transform('/map', ToFrame, T, Pose1),
  matrix_translation(Pose0, [X0,Y0,Z0]),
  matrix_translation(Pose1, [X1,Y1,Z1]),
  DX is X1-X0, DY is Y1-Y0, DZ is Z1-Z0,
  Distance is sqrt(DX*DX + DY*DY + DZ*DZ),
  QX is -DY, QY is DX, QZ is 0.0, QW is Distance + DZ,
  X is 0.5*(X0+X1), Y is 0.5*(Y0+Y1), Z is 0.5*(Z0+Z1),
  marker_scale(MarkerObject, [0.1,0.1,Distance]),
  marker_pose(MarkerObject, [X,Y,Z], [QW,QX,QY,QZ]).

marker_update(trail(Link), MarkerObject, T) :-
  ( atom(T) ; number(T) ),
  marker_update(trail(Link), MarkerObject, dt(T,0.5)).

marker_update(trail(Link), MarkerObject, dt(T,DT)) :-
  marker_update(trajectory(Link), MarkerObject, dt(T,DT)).

marker_update(trail(Link), MarkerObject, interval(T0,T1)) :-
  marker_update(trajectory(Link), MarkerObject, interval(T0,T1)).

marker_update(trajectory(Link), MarkerObject, T) :-
  ( atom(T) ; number(T) ),
  marker_update(trajectory(Link), MarkerObject, dt(T,0.5)).

marker_update(trajectory(Link), MarkerObject, dt(T0,DT)) :-
  jpl_call(MarkerObject, 'getChildren', [], ChildrenArray),
  jpl_array_to_list(ChildrenArray,Children),
  marker_update(trajectory(Link), MarkerObject, dt(T0,DT,T0,Children)).

marker_update(trajectory(_), _, dt(_,_,_,[])).

marker_update(trajectory(Link), MarkerObject, dt(T0,DT,T,[ChildObject|Rest])) :-
  object_lookup_transform(Link, T, (Translation,Orientation)),
  marker_pose(ChildObject, Translation, Orientation),
  T_next is T + DT,
  marker_update(trajectory(Link), MarkerObject, dt(T0,DT,T_next,Rest)).

marker_update(trajectory(Name), MarkerObject, interval(T0,T1)) :-
  jpl_call(MarkerObject, 'getChildren', [], ChildrenArray),
  jpl_array_to_list(ChildrenArray,Children),
  length(Children, NumSamples),
  T_diff is T1 - T0,
  DT is T_diff / NumSamples,
  marker_update(trajectory(Name), MarkerObject, dt(T0,DT)).

%marker_update(average_trajectory(Link), MarkerObject, (T0,T1,Interval)) :-
%  jpl_call(MarkerObject, 'clear', [], _),
%  false. % TODO

marker_update(_, MarkerObject, T) :-
  jpl_call(MarkerObject, 'getChildren', [], ChildrenArray),
  jpl_array_to_list(ChildrenArray,Children),
  forall(member(ChildObject,Children), ignore((
    marker(ChildTerm, ChildObject),
    marker_update(ChildTerm, ChildObject, T),
    marker_timestamp(ChildObject, T)
  ))).

% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % %
%
% Highlighting marker
%

marker_highlight(MarkerTerm) :-
  jpl_list_to_array([1.0,0.0,0.0,1.0], ColorArray),
  marker_highlight(MarkerTerm, ColorArray).

marker_highlight(MarkerTerm, [R,G,B]) :-
  jpl_list_to_array([R,G,B,1.0], ColorArray),
  marker_highlight(MarkerTerm, ColorArray).

marker_highlight(MarkerTerm, [R,G,B,A]) :-
  jpl_list_to_array([R,G,B,A], ColorArray),
  marker_highlight(MarkerTerm, ColorArray).

marker_highlight(MarkerTerm, ColorArg) :-
  compund(MarkerTerm),
  marker(MarkerTerm, MarkerObject),
  term_to_atom(MarkerTerm, MarkerAtom),
  marker_visualisation(MarkerVis),
  jpl_call(MarkerVis, 'highlight', [MarkerAtom, ColorArg], _),
  
  jpl_call(MarkerObject, 'getChildren', [], ChildrenArray),
  jpl_array_to_list(ChildrenArray,Children),
  forall(member(ChildObject,Children), ignore((
    marker(ChildTerm, ChildObject),
    marker_highlight(ChildTerm, ColorArg)
  ))).

marker_remove_highlight(MarkerTerm) :-
  compund(MarkerTerm),
  marker(MarkerTerm, _),
  term_to_atom(MarkerTerm, MarkerAtom),
  marker_visualisation(MarkerVis),
  jpl_call(MarkerVis, 'removeHighlight', [MarkerAtom], _),
  
  jpl_call(MarkerObject, 'getChildren', [], ChildrenArray),
  jpl_array_to_list(ChildrenArray,Children),
  forall(member(ChildObject,Children), ignore((
    marker(ChildTerm, ChildObject),
    marker_remove_highlight(ChildTerm)
  ))).
  
  

% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % %
%
% Marker properties
%

%marker_properties(Marker, Props) :-
%  var(Props),
%  false. % TODO: read all properties


marker_properties(Marker, [X|Args]) :-
  marker_property(Marker, X),
  marker_properties(Marker, Args).
marker_properties(_, []).


marker_property(Marker, type(Type)) :-
  marker_type(Marker, Type).

marker_property(Marker, color(Color)) :-
  marker_color(Marker, Color).

marker_property(Marker, scale(Scale)) :-
  marker_scale(Marker, Scale).

marker_property(Marker, pose(Position,Orientation)) :-
  marker_pose(Marker, Position, Orientation).

marker_property(Marker, mesh(Mesh)) :-
  marker_mesh_resource(Marker, Mesh).

marker_property(Marker, text(Text)) :-
  marker_text(Marker, Text).

marker_property(Marker, timestamp(T)) :-
  marker_timestamp(Marker, T).


marker_timestamp(Marker, T) :-
  marker_call(Marker,T,(get_marker_timestamp,set_marker_timestamp)).

marker_duration(Marker, Text) :-
  marker_call(Marker,Text,(get_marker_duration,set_marker_duration)).

marker_type(Marker, Type) :-
  marker_call(Marker,Type,(get_marker_type,set_marker_type)).

marker_scale(Marker, Scale) :-
  marker_call(Marker,Scale,(get_marker_scale,set_marker_scale)).

marker_color(Marker, Color) :-
  marker_call(Marker,Color,(get_marker_color,set_marker_color)).

marker_alpha(Marker, Alpha) :-
  marker_call(Marker,Alpha,(get_marker_alpha,set_marker_alpha)).

marker_mesh_resource(Marker, Mesh) :-
  marker_call(Marker,Mesh,(get_marker_mesh,set_marker_mesh)).

marker_pose(Marker, pose(Position,Orientation)) :-
  marker_call(Marker, pose(Position,Orientation), (get_marker_pose,set_marker_pose)).

marker_pose(Marker, Position, Orientation) :-
  marker_call(Marker, pose(Position,Orientation), (get_marker_pose,set_marker_pose)).

marker_orientation(Marker, Orientation) :-
  marker_call(Marker, Orientation, (get_marker_orientation,set_marker_orientation)).

marker_translation(Marker, Position) :-
  marker_call(Marker, Position, (get_marker_translation,set_marker_translation)).

marker_text(Marker, Text) :-
  marker_call(Marker,Text,(get_marker_text,set_marker_text)).

marker_has_visual(Marker, V) :-
  marker_call(Marker,V,(get_marker_has_visual,set_marker_has_visual)).


marker_call([Marker|Rest], Value, (Get,Set)) :-
  jpl_is_object(Marker),
  call(Set, Marker, Value),
  marker_call(Rest, Value, (Get,Set)).

marker_call([Marker|Rest], Value, (Get,Set)) :-
  marker(Marker,MarkerObj),
  marker_call([MarkerObj|Rest], Value, (Get,Set)).

marker_call([], _, _) :- true.

marker_call(Marker, Value, (Get,Set)) :-
  nonvar(Value), marker_call([Marker], Value, (Get,Set)).

marker_call(Marker, Value, (Get,_)) :-
  compound(Marker), var(Value),
  marker(Marker,MarkerObj),
  call(Get, MarkerObj, Value).

marker_call(Marker, Value, (Get,_)) :-
  jpl_is_object(Marker), var(Value),
  call(Get, Marker, Value).


% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % %
%
% Getter/Setter for marker messages
%
  
get_marker_timestamp(MarkerObj, T) :-
  jpl_call(MarkerObj, 'getTimestamp', [], T).

set_marker_timestamp(MarkerObj, T) :-
  jpl_call(MarkerObj, 'setTimestamp', [T], _).
  
get_marker_duration(MarkerObj, T) :-
  jpl_call(MarkerObj, 'getDuration', [], T).

set_marker_duration(MarkerObj, T) :-
  jpl_call(MarkerObj, 'setDuration', [T], _).

get_marker_has_visual(MarkerObj, true) :-
  jpl_call(MarkerObj, 'getHasVisual', [], @(true)).

get_marker_has_visual(MarkerObj, false) :-
  jpl_call(MarkerObj, 'getHasVisual', [], @(false)).

set_marker_has_visual(MarkerObj, true) :-
  jpl_call(MarkerObj, 'setHasVisual', [@(true)], _).

set_marker_has_visual(MarkerObj, false) :-
  jpl_call(MarkerObj, 'setHasVisual', [@(false)], _).

get_marker_type(MarkerObj, Type) :-
  jpl_call(MarkerObj, 'getType', [], TypeId),
  marker_type(Type, TypeId).

set_marker_type(MarkerObj, Type) :-
  marker_prop_type(Type, TypeId),
  jpl_call(MarkerObj, 'setType', [TypeId], _).

get_marker_mesh(MarkerObj, Mesh) :-
  jpl_call(MarkerObj, 'getMeshResource', [], Mesh).

set_marker_mesh(MarkerObj, Mesh) :-
  jpl_call(MarkerObj, 'setMeshResource', [Mesh], _).

get_marker_text(MarkerObj, Text) :-
  jpl_call(MarkerObj, 'getText', [], Text).

set_marker_text(MarkerObj, Text) :-
  jpl_call(MarkerObj, 'setText', [Text], _).

get_marker_scale(MarkerObj, [X,Y,Z]) :-
  jpl_call(MarkerObj, 'getScale', [], ScaleArray),
  jpl_array_to_list(ScaleArray, [X,Y,Z]).

set_marker_scale(MarkerObj, [X,Y,Z]) :-
  atom(X),atom(Y),atom(Z),
  atom_number(X,X_N),
  atom_number(Y,Y_N),
  atom_number(Z,Z_N),
  set_marker_scale(MarkerObj, [X_N,Y_N,Z_N]).

set_marker_scale(MarkerObj, [X,Y,Z]) :-
  number(X),number(Y),number(Z),
  jpl_list_to_array([X,Y,Z], ScaleArray),
  jpl_call(MarkerObj, 'setScale', [ScaleArray], _).

set_marker_scale(MarkerObj, Scale) :-
  number(Scale), set_marker_scale(MarkerObj, [Scale,Scale,Scale]).

get_marker_color(MarkerObj, [R,G,B,A]) :-
  jpl_call(MarkerObj, 'getColor', [], ColorArray),
  jpl_array_to_list(ColorArray,[R,G,B,A]).

set_marker_color(MarkerObj, [R,G,B,A]) :-
  atom(R),atom(G),atom(B),atom(A),
  atom_number(R,R_N),
  atom_number(G,G_N),
  atom_number(B,B_N),
  atom_number(A,A_N),
  set_marker_color(MarkerObj, [R_N,G_N,B_N,A_N]).

set_marker_color(MarkerObj, [R,G,B,A]) :-
  number(R),number(G),number(B),number(A),
  jpl_list_to_array([R,G,B,A], ColorArray),
  jpl_call(MarkerObj, 'setColor', [ColorArray], _).

set_marker_color(MarkerObj, Color) :-
  number(Color), set_marker_color(MarkerObj, [Color,Color,Color,1.0]).

get_marker_alpha(MarkerObj, A) :-
  jpl_call(MarkerObj, 'getAlpha', [], A).

set_marker_alpha(MarkerObj, A) :-
  atom(A), atom_number(A,A_N),
  set_marker_alpha(MarkerObj, A_N).

set_marker_alpha(MarkerObj, A) :-
  number(A),
  jpl_call(MarkerObj, 'setAlpha', [A], _).

get_marker_translation(MarkerObj, [X,Y,Z]) :-
  jpl_call(MarkerObj, 'getTranslation', [], TranslationArray),
  jpl_array_to_list(TranslationArray,[X,Y,Z]).

get_marker_orientation(MarkerObj, [QW,QX,QY,QZ]) :-
  jpl_call(MarkerObj, 'getOrientation', [], OrientationArray),
  jpl_array_to_list(OrientationArray,[QW,QX,QY,QZ]).

get_marker_pose(MarkerObj, pose(Translation,Orientation)) :-
  get_marker_translation(MarkerObj, Translation),
  get_marker_orientation(MarkerObj, Orientation).

set_marker_translation(MarkerObj, [X,Y,Z]) :-
  jpl_list_to_array([X,Y,Z], Array),
  jpl_call(MarkerObj, 'setTranslation', [Array], _).

set_marker_orientation(MarkerObj, [QW,QX,QY,QZ]) :-
  jpl_list_to_array([QW,QX,QY,QZ], Array),
  jpl_call(MarkerObj, 'setOrientation', [Array], _).

set_marker_pose(MarkerObj, pose(Translation,Orientation)) :-
  set_marker_translation(MarkerObj, Translation),
  set_marker_orientation(MarkerObj, Orientation).
