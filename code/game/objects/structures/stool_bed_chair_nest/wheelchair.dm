/obj/structure/bed/chair/wheelchair
	name = "wheelchair"
	desc = "You sit in this. Either by will or force."
	icon_state = "wheelchair"
	anchored = FALSE
	buckle_movable = TRUE

	var/driving = FALSE
	var/mob/living/pulling = null
	var/bloodiness
	var/next_sound = -1

/obj/structure/bed/chair/wheelchair/update_icon()
	return

/obj/structure/bed/chair/wheelchair/set_dir()
	..()
	overlays = null
	var/image/O = image(icon = 'icons/obj/bed_chair.dmi', icon_state = "w_overlay", layer = MOB_LAYER + 1.0, dir = dir)
	overlays += O
	if (buckled_mob)
		buckled_mob.set_dir(dir)

/obj/structure/bed/chair/wheelchair/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/wrench) || istype(W,/obj/item/stack) || istype(W, /obj/item/weapon/wirecutters))
		return
	..()

/obj/structure/bed/chair/wheelchair/relaymove(mob/user, direction)

	if (!..(user, direction))
		return

	// Redundant check?
	if (user.stat || user.stunned || user.weakened || user.paralysis || user.lying || user.restrained())
		if (user==pulling)
			pulling = null
			user.pulledby = null
			user << "<span class='warning'>You lost your grip!</span>"
		return
	if (buckled_mob && pulling && user == buckled_mob)
		if (pulling.stat || pulling.stunned || pulling.weakened || pulling.paralysis || pulling.lying || pulling.restrained())
			pulling.pulledby = null
			pulling = null
	if (user.pulling && (user == pulling))
		pulling = null
		user.pulledby = null
		return
	if (propelled)
		return
	if (pulling && (get_dist(src, pulling) > 1))
		pulling = null
		user.pulledby = null
		if (user==pulling)
			return
	if (pulling && (get_dir(loc, pulling.loc) == direction))
		user << "<span class='warning'>You cannot go there.</span>"
		return
	if (pulling && buckled_mob && (buckled_mob == user))
		user << "<span class='warning'>You cannot drive while being pushed.</span>"
		return

	// Let's roll
	driving = TRUE
	var/turf/T = null
	//--1---Move occupant---1--//
	if (buckled_mob)
		buckled_mob.buckled = null
		step(buckled_mob, direction)
		buckled_mob.buckled = src
	//--2----Move driver----2--//
	if (pulling)
		T = pulling.loc
		if (get_dist(src, pulling) >= 1)
			step(pulling, get_dir(pulling.loc, loc))
	//--3--Move wheelchair--3--//
	step(src, direction)
	if (buckled_mob) // Make sure it stays beneath the occupant
		Move(buckled_mob.loc)
	set_dir(direction)
	if (pulling) // Driver
		if (pulling.loc == loc) // We moved onto the wheelchair? Revert!
			pulling.forceMove(T)
		else
			spawn(0)
			if (get_dist(src, pulling) > 1) // We are too far away? Losing control.
				pulling = null
				user.pulledby = null
			pulling.set_dir(get_dir(pulling, src)) // When everything is right, face the wheelchair
	if (bloodiness)
		create_track()
	driving = FALSE

/obj/structure/bed/chair/wheelchair/Move()
	var/oloc = loc
	..()
	if (oloc != loc)
		if (world.time > next_sound)
			playsound(get_turf(src), 'sound/effects/rollermove.ogg', 75, TRUE)
			next_sound = world.time + 10

	if (buckled_mob)
		var/mob/living/occupant = buckled_mob
		if (!driving)
			occupant.buckled = null
			occupant.Move(loc)
			occupant.buckled = src
			if (occupant && (loc != occupant.loc))
				if (propelled)
					for (var/mob/O in loc)
						if (O != occupant)
							Bump(O)
				else
					unbuckle_mob()
			if (pulling && (get_dist(src, pulling) > 1))
				pulling.pulledby = null
				pulling << "<span class='warning'>You lost your grip!</span>"
				pulling = null
		else
			if (occupant && (loc != occupant.loc))
				forceMove(occupant.loc) // Failsafe to make sure the wheelchair stays beneath the occupant after driving

/obj/structure/bed/chair/wheelchair/attack_hand(mob/living/user as mob)
	if (pulling)
		MouseDrop(usr)
	else
		user_unbuckle_mob(user)
	return
/* removed this incredibly dumb feature - Kachnov
/obj/structure/bed/chair/wheelchair/CtrlClick(var/mob/user)
	if (in_range(src, user))
		if (!ishuman(user))	return
		if (user == buckled_mob)
			user << "<span class='warning'>You realize you are unable to push the wheelchair you sit in.</span>"
			return
		if (!pulling)
			pulling = user
			user.pulledby = src
			if (user.pulling)
				user.stop_pulling()
			user.set_dir(get_dir(user, src))
			user << "You grip \the [name]'s handles."
		else
			usr << "You let go of \the [name]'s handles."
			pulling.pulledby = null
			pulling = null
		return
*/
/obj/structure/bed/chair/wheelchair/Bump(atom/A)
	..()
	if (!buckled_mob)	return

	if (propelled || (pulling && (pulling.a_intent == I_HARM)))
		var/mob/living/occupant = unbuckle_mob()

		if (pulling && (pulling.a_intent == I_HARM))
			occupant.throw_at(A, 3, 3, pulling)
		else if (propelled)
			occupant.throw_at(A, 3, propelled)

		var/def_zone = ran_zone()
		var/blocked = occupant.run_armor_check(def_zone, "melee")
		occupant.throw_at(A, 3, propelled)
		occupant.apply_effect(6, STUN, blocked)
		occupant.apply_effect(6, WEAKEN, blocked)
		occupant.apply_effect(6, STUTTER, blocked)
		occupant.apply_damage(10, BRUTE, def_zone)
		playsound(loc, 'sound/weapons/punch1.ogg', 50, TRUE, -1)
		if (istype(A, /mob/living))
			var/mob/living/victim = A
			def_zone = ran_zone()
			blocked = victim.run_armor_check(def_zone, "melee")
			victim.apply_effect(6, STUN, blocked)
			victim.apply_effect(6, WEAKEN, blocked)
			victim.apply_effect(6, STUTTER, blocked)
			victim.apply_damage(10, BRUTE, def_zone)
		if (pulling)
			occupant.visible_message("<span class='danger'>[pulling] has thrusted \the [name] into \the [A], throwing \the [occupant] out of it!</span>")

			pulling.attack_log += "\[[time_stamp()]\]<font color='red'> Crashed [occupant.name]'s ([occupant.ckey]) [name] into \a [A]</font>"
			occupant.attack_log += "\[[time_stamp()]\]<font color='orange'> Thrusted into \a [A] by [pulling.name] ([pulling.ckey]) with \the [name]</font>"
			msg_admin_attack("[pulling.name] ([pulling.ckey]) has thrusted [occupant.name]'s ([occupant.ckey]) [name] into \a [A] (<A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[pulling.x];Y=[pulling.y];Z=[pulling.z]'>JMP</a>)", pulling.ckey, occupant.ckey)
		else
			occupant.visible_message("<span class='danger'>[occupant] crashed into \the [A]!</span>")

/obj/structure/bed/chair/wheelchair/proc/create_track()
	var/obj/effect/decal/cleanable/blood/tracks/B = new(loc)
	var/newdir = get_dir(get_step(loc, dir), loc)
	if (newdir == dir)
		B.set_dir(newdir)
	else
		newdir = newdir | dir
		if (newdir == 3)
			newdir = TRUE
		else if (newdir == 12)
			newdir = 4
		B.set_dir(newdir)
	bloodiness--

/obj/structure/bed/chair/wheelchair/buckle_mob(mob/M as mob, mob/user as mob)
	if (M == pulling)
		pulling = null
		usr.pulledby = null
	..()
