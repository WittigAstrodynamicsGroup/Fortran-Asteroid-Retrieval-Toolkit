! ============================================================
!
!
!
!     ASTEROID PRUNING PRE-FILTER: FORTRAN08 IMPLEMENTATION
!
!
!
! =============================================================
!
!   INTRODUCTION
!   ------------
!   The below program is essentially four nested do-loops that apply the 
!   pre-filtering methodology to every candidate in the minor bodies
!   database and target OE files.
!
!   LIST OF DEPENDENCIES
!   --------------------
!   DynamicalArrays (included as a module)
!   OpenMP
!   gFortran with --free-fform
!   Minor bodies database as .csv
!   Target OE files as .csv
!
!   METADATA
!   --------
!   Date: 31/03/18
!   Author: Jack Tyler
!
!   CHANGELOG
!   ---------
!   1/4/18: Bug fixes
!   3/4/18: Update for Lyceum & parameterise by input date
!


program main

    use omp_lib
    implicit none

    integer :: nthreads = 16 ! Number of threads to use
    integer :: unitno, candidatecount, itercount, threadno
    integer :: i, j, k ! Loop variables
    integer :: bodyID
    integer :: desiredtime
    integer :: index = 1

    real :: a_b, e_b, inb, rp_t, e_t, in_t, start, finish
    real :: mindV, au
    real :: t1, t2, t3, t4, t5, date, o, Om, M, p, M_t


    integer, dimension(17719) :: database

    real, dimension(1353, 3) :: bodyData
    real, dimension(3046544,4) :: targetData

    character(len=260) :: bodystring, filepath
    character(len=8) :: fmt = '(I7.7)'
    character(len=11) :: desiredtimestring

    candidatecount = 0
    itercount = 0
    au =  1.495978707e8
    filepath = 'corrected_oe/'

    ! Print welcome message

    write(*,*) "============================================================"
    write(*,*) " "
    write(*,*) "ASTEROID PRUNING PRE-FILTER: FORTRAN08 IMPLEMENTATION"
    write(*,*) " "
    write(*,*) "LYCEUM VERSION: LIMITED PRINTING CAPABILITIES AVAILABLE"
    write(*,*) " "
    write(*,*) "DESIGNED FOR USE WITH 16 THREADS"
    write(*,*) " "
    write(*,*) "============================================================"

    ! Initialise OMP and delete current results.txt

    call OMP_SET_NUM_THREADS(nthreads)    
    call get_command_argument(index, desiredtimestring)
    call file_check(desiredtimestring)
    call system('ulimit -s unlimited')
    read(desiredtimestring, '(I7)') desiredtime

    ! write(*,*) desiredtime

    ! Load data sets

    write(*,*) "Loading data sets..."

    open(unit=3, file="target_csv.csv")    ! Target OEs

    do i = 1,3046544

        read(3,*) targetData(i,1), targetData(i,2), targetData(i,3),t1,t2,targetData(i,4),t4,t5

    end do

    close(3)

    open(unit=20, file="Database_SPKs.csv")   ! Database file
    
    read(20,*) ! Read once to avoid 'spk_id' header

    do i = 1,size(database)
	    read(20,*) database(i)
    end do

    close(20)

	open(99,file="results_new/results_"//trim(desiredtimestring)//".txt")

    ! Write progress message and begin timing

    write(*,*) "Loading complete. Beginning compute sequence for body #", desiredtimestring
    start = omp_get_wtime()

    !$OMP PARALLEL DO PRIVATE(I,J,K, bodyid, bodystring, unitno, mindV, bodyData, a_b, e_b, inb, rp_t, e_t, in_t, M_t)
    do i = 1, size(database)! All bodies

        bodyID = database(i)
        write(bodystring, fmt) bodyID
	call system('ulimit -s unlimited')
        unitno = OMP_GET_THREAD_NUM() + 30

        open(unit=unitno, file=trim(filepath)//trim(bodystring)//'_OE_corr.csv')
    
        do j = 1,1353
            read(unitno,*) date, bodyData(j,1), bodyData(j,2), bodyData(j,3), o, O, M, p
        end do

        close(unitno)

        ! exitloop: do j = 272,1353
        exitloop:  do j = desiredtime, desiredtime

            a_b = bodyData(j,1)*au
            e_b = bodyData(j,2)
            inb = bodyData(j,3)

            do k = 1,3046544
                
                rp_t = targetData(k,1)*au
                e_t = targetData(k,2)
                in_t = targetData(k,3)
				M_t = targetData(k,4)

                call cheapest(a_b, e_b, inb, rp_t, e_t, in_t, M_t, mindV)

                if (mindV < .7) then 

                    call file_add(bodyID, unitno, mindv, k, desiredtimestring)
                    candidatecount = candidatecount + 1
		            exit exitloop

                end if

            end do

        end do exitloop

        itercount = itercount + 1
	write(*,*) "Completed processing object #", itercount

    end do
    !$OMP END PARALLEL DO

    finish = omp_get_wtime()

    write(*,*) "==================== Scan completed ========================"
    write(*,*) "Date performed: ", desiredtimestring
    write(*,*) "Objects scanned: ", itercount
    write(*,*) "Candidates found: ", candidatecount
    write(*,*) "Compute time: ", finish-start, "seconds."
    write(*,*) "============================================================"

end program main


subroutine file_add(bodyID, unitnum, mindv, k, desiredtimestring)

    ! Subroutine intents

    character(len=50) :: filepath ! Define address of file to be read

    integer, intent(in) :: bodyID
    integer, intent(in) :: unitnum
    integer, intent(in) :: k
    
    real, intent(in) :: mindv

    character(len=11), intent(in) :: desiredtimestring

    character(len=11) :: outstring

    logical :: exist

    call where_from(k, outstring)

    filepath = "results_new/results_"//trim(desiredtimestring)//".txt"

    inquire(file=trim(filepath), exist=exist)

!    if (exist) then
!
!     open(99, file=trim(filepath), status="old", position="append", action="write")
!
!   else
!
!     open(99, file=trim(filepath), status="new", action="write")
!
!  end if
!
    write(99, *) bodyID, mindv, outstring
!    close(unitnum)

end subroutine file_add


subroutine file_check(desiredtimestring)

    character(len=11), intent(in) :: desiredtimestring

    character(len=50) :: filepath
    logical :: exist

    filepath = "results_new/results_"//trim(desiredtimestring)//".txt"

    inquire(file=trim(filepath), exist=exist)

    if (exist) then

        open(20, file=trim(filepath))
        close(20, status='delete')

    end if

end subroutine file_check


subroutine where_from(k, outstring)

    integer, intent(in) :: k
    character(len=11), intent(out) :: outstring

    if (k <= 719640) then

        outstring = "Halo L1 N"

    else if (k > 719640 .AND. k <= 1439280) then

        outstring = "Halo L1 S"

    else if (k > 1439280 .AND. k <= 2091600) then

        outstring = "Halo L2 S"

    else if (k > 2091600 .AND. k <= 2791440) then

        outstring = "Halo L2 N"

    else if (k > 2791440 .AND. k <= 2800674) then

        outstring = "Planar L1"

    else if (k > 2800674 .AND. k <= 2823714) then

        outstring = "Vrtcl. L1"

    else

        outstring = "Vrtcl. L2"

    end if

end subroutine where_from


subroutine cheapest(a_b, e_b, inb, rp_t, e_t, in_t, M_t, cheap)

    real, intent(in) :: a_b, e_b, inb, rp_t, e_t, in_t, M_t
    real, intent(out) :: cheap
    real :: mu_s, a_t, ra_t, rp_b, ra_b, a_int, in_b
    real :: dV1, dV2, dV3, dV4
    real :: dVi1, dVi2, dVi3, dVi5, dVi6, dVi7, dVi4, dVi8
    real :: v1, v2, v3, v5, v6, v7
    double precision :: pi = 4.*datan(1.d0)
    real :: rt

    mu_s = 1.327124400189e11

    in_b = inb*pi/180

    ra_b = a_b*(1+e_b)    ! if (r+)
    rp_b = a_b*(1-e_b)

    a_t = rp_t/(1-e_t)
    rt = a_t*(1-e_t**2)/(1+e_t*cos(M_t))
    ra_t = a_t*(1+e_t)

    ! First case: perihelion modifying aphelion

    ! a_int = (rp_b+rt)/2

    ! dV1 = sqrt(mu_s*(2/rp_b-1/a_int))-sqrt(mu_s*(2/rp_b-1/a_b)) 
    ! dV2 = sqrt(mu_s*(2/rt-1/a_t))-sqrt(mu_s*(2/rt-1/a_int))

    ! dVi1 = 2*sqrt((mu_s/a_b)*(ra_b/rp_b))*sin(abs(in_b-in_t)/2)

    ! if (r+)


    ! a_t = rp_t/(1-e_t) 
    ! ra_t = a_t*(1+e_t) 

    ! There are 16 cases of different transfer possibilities. 

    !! Cases 1-4: target rt, perform periapsis changing apoapsis first

    a_int = .5*(rp_b+rt) 

    dV1 = sqrt(mu_s*(2/rp_b-1/a_int))-sqrt(mu_s*(2/rp_b-1/a_b)) 
    dV2 = sqrt(mu_s*(2/rt-1/a_t)) - sqrt(mu_s*(2/rt-1/a_int)) 

    dVi1 = 2*sqrt((mu_s/a_b)*(ra_b/rp_b))*sin(abs(in_b-in_t)/2)

    if (rt>rp_b) then

        
        dVi2 = 2*sqrt((mu_s/a_int) * (rt/rp_b))*sin(abs(in_b-in_t)/2)
	dVi3 = 2*sqrt((mu_s/a_int) * (rp_b/rt))*sin(abs(in_b-in_t)/2) 

    else

        dVi2 = 2*sqrt((mu_s/a_int)*(rp_b/rt))*sin(abs(in_b-in_t)/2)
	dVi3 = 2*sqrt((mu_s/a_int)*(rt/rp_b))*sin(abs(in_b-in_t)/2) 

    end if

    ! dVi4 = 2*sqrt((mu_s/a_t)*(rp_b/rt))*sin(abs(in_b-in_t)/2) 

    v1 = sqrt(dV1**2+dVi1**2) + sqrt(dV2**2)
    v2 = sqrt(dV1**2+dVi2**2) + sqrt(dV2**2) 
    v3 = sqrt(dV1**2) + sqrt(dVi3**2+dV2**2) 

    ! !! Cases 5:8: target rt, perform apoapsis changing periapsis first

    a_int = .5*(rt+ra_b) 

    dVi5 = 2*sqrt((mu_s/a_b)*(rp_b/ra_b))*sin(abs(in_b-in_t)/2)

    dV3 = sqrt(mu_s*(2/ra_b-1/a_int))-sqrt(mu_s*(2/ra_b-1/a_b))
    dV4 = sqrt(mu_s*(2/rt-1/a_t))-sqrt(mu_s*(2/rt-1/a_int))

    if (rt > ra_b) then

        dVi6 = 2*sqrt((mu_s/a_int)*(ra_b/rt))*sin(abs(in_b-in_t)/2)
	dVi7 = 2*sqrt((mu_s/a_int)*(rt/ra_b))*sin(abs(in_b-in_t)/2)

    else

        dVi6 = 2*sqrt((mu_s/a_int)*(rt/ra_b))*sin(abs(in_b-in_t)/2) 
	dVi7 = 2*sqrt((mu_s/a_int)*(ra_b/rt))*sin(abs(in_b-in_t)/2)

    end if


    ! dVi8 = 2*sqrt((mu_s/a_t)*ra_t/rp_t)*sin(abs(in_b-in_t)/2) 

    v5 = sqrt(dVi5**2+dV3**2)+sqrt(dV4**2) 
    v6 = sqrt(dVi6**2+dV3**2)+sqrt(dV4**2)
    v7 = sqrt(dV3**2) + sqrt(dV4**2+dVi7**2) 

    ! !! Cases 9-12: target ra_t, perform periapsis changing apoapsis first

    ! a_int = .5*(ra_t+rp_b) 

    ! dV5 = sqrt(mu_s*(2/rp_b-1/a_int))-sqrt(mu_s*(2/rp_b-1/a_b)) 
    ! dV6 = sqrt(mu_s*(2/ra_t-1/a_t)) - sqrt(mu_s*(2/ra_t-1/a_int)) 

    ! dVi9 = 2*sqrt((mu_s/a_b)*(ra_b/rp_b))*sin(abs(in_b-in_t)/2) 

    ! if (ra_t > rp_b) then

    !     dVi10 = 2*sqrt((mu_s/a_int)*ra_t/rp_b)*sin(abs(in_b-in_t)/2) 
    !     dVi11 = 2*sqrt((mu_s/a_int)*rp_b/ra_t)*sin(abs(in_b-in_t)/2) 
        
    ! else

    !     dVi10 = 2*sqrt((mu_s/a_int)*rp_b/ra_t)*sin(abs(in_b-in_t)/2) 
    !     dVi11 = 2*sqrt((mu_s/a_int)*ra_t/rp_b)*sin(abs(in_b-in_t)/2) 
        
    ! end if

    ! dVi12 = 2*sqrt((mu_s/a_t)*(rp_t)/ra_t)*sin(abs(in_b-in_t)/2) 

    ! v9 = sqrt(dVi9**2+dV5**2)+sqrt(dV6**2) 
    ! v10 = sqrt(dV5**2+dVi10**2)+sqrt(dV6**2) 
    ! v11 = sqrt(dV5**2) + sqrt(dV6**2+dVi11**2) 
    ! v12 = sqrt(dV5**2) + sqrt(dV6**2+dVi12**2) 

    ! !! Cases 13-16: target ra_t, perform ap changing peri first

    ! a_int = .5*(ra_b+ra_t) 

    ! dV7 = sqrt(mu_s*(2/ra_b-1/a_int))-sqrt(mu_s*(2/ra_b-1/a_b)) 
    ! dV8 = sqrt(mu_s*(2/ra_t-1/a_t))-sqrt(mu_s*(2/ra_t-1/a_int)) 

    ! dVi13 = 2*sqrt(mu_s/a_b*(rp_b/ra_b))*sin(abs(in_b-in_t)) 

    ! if (ra_b > ra_t) then

    !     dVi14 = 2*sqrt(mu_s/a_int*ra_t/ra_b)*sin(abs(in_b-in_t)) 
    !     dVi15 = 2*sqrt(mu_s/a_int*ra_b/ra_t)*sin(abs(in_b-in_t)) 

    ! else

    !     dVi14 = 2*sqrt(mu_s/a_int*ra_b/ra_t)*sin(abs(in_b-in_t)) 
    !     dVi15 = 2*sqrt(mu_s/a_int*ra_t/ra_b)*sin(abs(in_b-in_t)) 

    ! end if

    ! dVi16 = 2*sqrt(mu_s/a_int*(ra_t/rp_t))*sin(abs(in_b-in_t)) 

    ! v13 = sqrt(dVi13**2+dV7**2)+sqrt(dV8**2) 
    ! v14 = sqrt(dV7**2+dVi14**2)+sqrt(dV8**2) 
    ! v15 = sqrt(dV7**2) + sqrt(dV8**2+dVi15**2) 
    ! v16 = sqrt(dV7**2) + sqrt(dV8**2+dVi16**2) 

    cheap = min(v1, v2, v3, v5, v6, v7)

end subroutine cheapest
