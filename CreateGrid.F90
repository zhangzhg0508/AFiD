!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!                                                         ! 
!    FILE: CreateGrid.F90                                 !
!    CONTAINS: subroutine CreateGrid                      !
!                                                         ! 
!    PURPOSE: Compute the indices, grid, grid metrics     !
!     and coefficients for differentiation                !
!                                                         !
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

      subroutine CreateGrid
      use param
      use AuxiliaryRoutines
      implicit none

      real :: x1,x2,x3
      real :: a33, a33m, a33p
      real :: delet, etain, tstr3
      real :: z2dp

      real, allocatable, dimension(:) :: etaz, etazm

      integer :: i, j, kc, km, kp
      integer :: nxmo, nclip


      do kc=1,nxm
        kmv(kc)=kc-1
        kpv(kc)=kc+1
        if(kc.eq.1) kmv(kc)=kc
        if(kc.eq.nxm) kpv(kc)=kc
      end do

      do kc=1,nxm
        kpc(kc)=kpv(kc)-kc
        kmc(kc)=kc-kmv(kc)
      end do


!
!     UNIFORM (HORIZONTAL DIRECTIONS) GRID
!
       do  i=1,nz
        x1=real(i-1)/real(nzm)
        zc(i)= zlen*x1
       end do

       do i=1,nzm
         zm(i)=(zc(i)+zc(i+1))*0.5d0
       end do

       do j=1,ny
        x2=real(j-1)/real(nym)
        yc(j)= ylen*x2
       end do

       do j=1,nym
        ym(j)=(yc(j)+yc(j+1))*0.5d0
       end do

!
!     VERTICAL COORDINATE DEFINITION
!
!     OPTION 0: UNIFORM CLUSTERING
!
      call AllocateReal1DArray(etaz,1,nx+500)
      call AllocateReal1DArray(etazm,1,nx+500)

      if (istr3.eq.0) then
        do kc=1,nx
          x3=real(kc-1)/real(nxm)
          etaz(kc)=alx3*x3
          xc(kc)=etaz(kc)
        enddo
      endif

!
!     OPTION 4: HYPERBOLIC TANGENT-TYPE CLUSTERING
!

        tstr3=tanh(str3)

        if (istr3.eq.4) then
         xc(1)=0.0d0
         do kc=2,nx
          z2dp=float(2*kc-nx-1)/float(nxm)
          xc(kc)=(1+tanh(str3*z2dp)/tstr3)*0.5*alx3
          if(xc(kc).lt.0.or.xc(kc).gt.alx3)then
           write(*,*)'Grid is too streched: ','zc(',kc,')=',xc(kc)
           stop
          endif
         end do
        end if

!
!     OPTION 6: CLIPPED CHEBYCHEV-TYPE CLUSTERING
!


      if(istr3.eq.6) then
      nclip = int(str3)
      nxmo = nx+nclip+nclip
      do kc=1,nxmo
        etazm(kc)=+cos(pi*(float(kc)-0.5)/float(nxmo))
      end do
      do kc=1,nx
        etaz(kc)=etazm(kc+nclip)
      end do
      delet = etaz(1)-etaz(nx)
      etain = etaz(1)
      do kc=1,nx
        etaz(kc)=etaz(kc)/(0.5*delet)
      end do
      xc(1) = 0.
      do kc=2,nxm
        xc(kc) = alx3*(1.-etaz(kc))*0.5
      end do
      xc(nx) = alx3
      endif

      call DestroyReal1DArray(etaz)
      call DestroyReal1DArray(etazm)
      
!m-----------------------------------------
!
!     METRIC FOR UNIFORM DIRECTIONS
!

      dx=real(nxm)/alx3
      dy=real(nym)/ylen
      dz=real(nzm)/zlen

      dxq=dx*dx                                                      
      dyq=dy*dy                                                      
      dzq=dz*dz                                                      

!
!     STAGGERED COORDINATES AND
!     METRIC QUANTITIES FOR NON-UNIFORM 
!     DIRECTIONS
!

      do kc=1,nxm
        xm(kc)=(xc(kc)+xc(kc+1))*0.5d0
        g3rm(kc)=(xc(kc+1)-xc(kc))*dx
      enddo
      do kc=2,nxm
        g3rc(kc)=(xc(kc+1)-xc(kc-1))*dx*0.5d0
      enddo
      g3rc(1)=(xc(2)-xc(1))*dx
      g3rc(nx)= (xc(nx)-xc(nxm))*dx
!
!     WRITE GRID INFORMATION
!
      do kc=1,nxm
        udx3m(kc) = dx/g3rm(kc)
        udx3c(kc) = dx/g3rc(kc)
      end do
      udx3c(nx) = dx/g3rc(nx)
!m====================================================
      if(ismaster) then
      open(unit=78,file='axicor.out',status='unknown')
      do kc=1,nx
        write(78,345) kc,xc(kc),xm(kc),g3rc(kc),g3rm(kc)
      end do
      close(78)
 345  format(i4,4(2x,e23.15))
!m===================================================
!
!     QUANTITIES FOR DERIVATIVES
!
      open(unit=78,file='fact3.out',status='unknown')
      do kc=1,nxm
        write(78,*) kc,udx3m(kc),udx3c(kc)
      end do
        write(78,*) nx,udx3m(nxm),udx3c(nx)
      close(78)
      endif

!
!    COEFFICIENTS FOR DIFFERENTIATION FOR NON-UNIFORM GRID
!
!    Q3 DIFFERENTIATION (CENTERED VARIABLE)
!

      am3ck(1)=0.d0
      ap3ck(1)=0.d0
      ac3ck(1)=1.d0
      am3ck(nx)=0.d0
      ap3ck(nx)=0.d0
      ac3ck(nx)=1.d0

      do kc=2,nxm
       km=kc-1
       kp=kc+1
       a33=dxq/g3rc(kc)
       a33p=1.d0/g3rm(kc)
       a33m=1.d0/g3rm(km)
       ap3ck(kc)=a33*a33p
       am3ck(kc)=a33*a33m
       ac3ck(kc)=-(ap3ck(kc)+am3ck(kc))
      enddo

!
!    Q1/Q2 DIFFERENTIATION (STAGGERED VARIABLE)
!
!

      do kc=2,nxm-1
      kp=kc+1
      km=kc-1
      a33=dxq/g3rm(kc)
      a33p= +a33/g3rc(kp)
      a33m= +a33/g3rc(kc)
      ap3sk(kc)=a33p
      am3sk(kc)=a33m
      ac3sk(kc)=-(ap3sk(kc)+am3sk(kc))
      enddo
!    
!    LOWER WALL BOUNDARY CONDITIONS (INSLWS SETS NO-SLIP vs STRESS-FREE WALL)
!    
      kc=1
      kp=kc+1
      a33=dxq/g3rm(kc)
      a33p= +a33/g3rc(kp)
      a33m= +a33/g3rc(kc)
      ap3sk(kc)=a33p
      am3sk(kc)=0.d0
      ac3sk(kc)=-(a33p+inslws*a33m*2.d0)

!    
!    UPPER WALL BOUNDARY CONDITIONS (INSLWN SETS NO-SLIP vs STRESS-FREE WALL)
!    

      kc=nxm
      kp=kc+1
      a33=dxq/g3rm(kc)
      a33p= +a33/g3rc(kp)
      a33m= +a33/g3rc(kc)
      am3sk(kc)=a33m
      ap3sk(kc)=0.d0
      ac3sk(kc)=-(a33m+inslwn*a33p*2.d0)

      am3ssk(1)=0.d0
      ap3ssk(1)=0.d0
      ac3ssk(1)=1.d0

!
!    TEMPERATURE DIFFERENTIATION (CENTERED VARIABLE)
!


      do kc=2,nxm
       kp=kc+1
       km=kc-1
       a33=dxq/g3rc(kc)
       a33p=1.d0/g3rm(kc)
       a33m=1.d0/g3rm(km)
       ap3ssk(kc)=a33*a33p
       am3ssk(kc)=a33*a33m
       ac3ssk(kc)=-(ap3ssk(kc)+am3ssk(kc))
      enddo

      am3ssk(nx)=0.d0
      ap3ssk(nx)=0.d0
      ac3ssk(nx)=1.d0

      return                                                            
      end                                                               

