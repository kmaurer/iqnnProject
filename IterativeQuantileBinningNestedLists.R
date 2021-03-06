### CODE DISCONTINUED -- ONLY KEEP IN CASE SECTIONS NEED TO CROSSCHECK LATER

#--------------------------------------
### Iterative Quantile Binning version 2 with nested list structured bin definitions
# Input:
#   dat = data frame to be binned (will coerce matrix or tibble to simple data frame)
#   bin_cols = vector of column names of variables to iteratively bin, ordered first to last
#   nbins = vector of number of bins per step of iterative binning, ordered first to last
#   jit = vector of margins for uniform jitter to each dimension to create seperability of tied obs due to finite precision
iterative_quant_bin2 <- function(data, bin_cols, nbins, output="data",jit = rep(0,length(bin_cols))){
  data <- as.data.frame(data)
  bin_dim <- length(nbins)
  bin_data <- matrix(NA,nrow=nrow(data),ncol=bin_dim, dimnames=list(row.names(data),paste(bin_cols,"binned",sep="_")))
  # Initialize with first binning step
  step_bin_info <- quant_bin_1d(data[,bin_cols[1]], nbins[1],output="both",jit[1])
  bin_bounds <- matrix(c(step_bin_info$bin_bounds[1:nbins[1]],
                         step_bin_info$bin_bounds[2:(nbins[1]+1)]),
                       nrow=nbins[1],byrow=FALSE )
  bin_centers <- matrix(step_bin_info$bin_centers, nrow=nbins[1])
  bin_data[,1] <- step_bin_info$bin_data
  # Loop over remaining variables to use quantile binning WITHIN each of previous state bins
  for(d in 2:bin_dim){
    stack_size <- nrow(bin_centers)
    stack_matrix <- make_stack_matrix(stack_size,nbins[d])
    bin_centers <- cbind(stack_matrix %*% bin_centers,matrix(rep(NA,stack_size*nbins[d]),ncol=1))
    bin_bounds <- cbind(stack_matrix %*% bin_bounds,matrix(rep(NA,2*stack_size*nbins[d]),ncol=2))
    # iterate through unique bins from prior step which are the {1,1+nbins[d],1+2*nbins[d],...} rows of the bin matrices
    for(b in seq(1,1+(stack_size-1)*nbins[d],by=nbins[d]) ){
      in_bin_b <- apply(matrix(bin_data[,1:(d-1)],ncol=(d-1)),1,identical,y=bin_centers[b,-d])
      step_bin_info <- quant_bin_1d(data[in_bin_b,bin_cols[d]], nbins[d],output="both",jit[d])
      bin_bounds[b:(b+nbins[d]-1),c(2*d-1,2*d)] <- matrix(c(step_bin_info$bin_bounds[1:nbins[d]],
                                                            step_bin_info$bin_bounds[2:(nbins[d]+1)]),
                                                          nrow=nbins[d],byrow=FALSE)
      bin_centers[b:(b+nbins[d]-1),d] <- matrix(step_bin_info$bin_centers, nrow=nbins[d])
      bin_data[in_bin_b,d] <- step_bin_info$bin_data
    }
  }
  
  bin_list <- make_bin_list(bin_bounds,nbins)
  if(output=="data") return(list(dat=dat,bin_dat=bin_dat))
  if(output=="definition") return(list(bin_centers=bin_centers, bin_bounds=bin_bounds,bin_cols=bin_cols, nbins=nbins, jit=jit, bin_list=bin_list))
  if(output=="both"){
    return(list(bin_dat=list(dat=dat,bin_dat=bin_dat), 
                bin_def=list(bin_centers=bin_centers, bin_bounds=bin_bounds, bin_cols=bin_cols, nbins=nbins, jit=jit,bin_list=bin_list)))
  } 
}

bin_def <- iterative_quant_bin2(data=iris, bin_cols=c("Sepal.Length","Sepal.Width","Petal.Width"),
                             nbins=c(3,5,2), output="definition",jit=rep(0.001,3))
str(bin_def)


make_bin_list <- function(bin_bounds,nbins){
  bin_dim = length(nbins)
  ### build nested list version of bin_bounds to speed up future searching for bins
  lower_level_list <- list(NULL)
  for(i in 1:nrow(bin_bounds)){
    lower_level_list[[i]] <- i
  } 
  for(d in bin_dim:1){
    # for each dimension from second lowest to highest, group up observations from lower_level_list into items in upper_level_list 
    upper_level_list <- list(NULL)
    upper_blocks <- ifelse(d==1,1,prod(nbins[1:(d-1)]))
    lower_block_size <- nbins[d]
    
    upper_indeces <- prod(nbins[d:length(nbins)])
    lower_indeces <- ifelse(d==bin_dim,1,prod(nbins[(d+1):bin_dim]))
    
    for(ul in 1:upper_blocks){
      # create upper level groups 
      upper_level_list[[ul]] <- list(NULL)
      for(ll in 1:lower_block_size){
        upper_level_list[[ul]][[ll]] <- lower_level_list[[(ul-1)*lower_block_size+ll]]
      }
      upper_level_list[[ul]][[lower_block_size+1]] <- bin_bounds[(ul-1)*upper_indeces + 1:lower_block_size*lower_indeces,(d-1)*2+1:2]
    }
    lower_level_list <- upper_level_list
  }
  bin_list <- lower_level_list
  return(bin_list)
}

bin_list <- make_bin_list(iq_def$bin_bounds, iq_def$nbins)
x<- iris[118,c(1,2,4)]




bin_index_finder2 <- function(x, bin_def, strict=TRUE){ 
  bin_dim = length(bin_def$nbins)
  nest_list <- bin_def$bin_list[[1]]
  if(strict==TRUE) {
    for(d in 1:bin_dim){
      nest_index <- which(x[[d]] > nest_list[[bin_def$nbins[d]+1]][,1] & x[[d]] < nest_list[[bin_def$nbins[d]+1]][,2])
      nest_list <- nest_list[[nest_index]]
    }
    idx <- nest_list
  }else{
  return(1)
  }
  return(idx)
} 


### Is it faster?
baseball <- read.csv("http://kmaurer.github.io/documents/SLahman_Batting2014.csv")
head(baseball)

baseball <- na.omit(baseball %>%
                      select(playerID:HR))

bb_players <- baseball %>%
  select(playerID:HR, -lgID) %>%
  mutate(hit_rate = H/G) %>%
  arrange(playerID, yearID) %>%
  group_by(playerID) %>%
  summarise(hr = sum(HR,na.rm=TRUE),
            b2 = sum(X2B,na.rm=TRUE),
            b3 = sum(X3B,na.rm=TRUE),
            hit = sum(H,na.rm=TRUE),
            ab = sum(AB,na.rm=TRUE))
bb_players <- as.data.frame(na.omit(bb_players))
head(bb_players)

iq_def <- iterative_quant_bin2(dat=bb_players, bin_cols=c("b2","b3","hit","ab"),
                    nbins=c(7,7,6,6), jit=rep(0.001,4), output="definition")
bin_list <- make_bin_list(iq_def$bin_bounds, iq_def$nbins)

runs=100000
timer <- Sys.time()
for(i in 1:runs){
bin_index_finder2(bb_players[1,c("b2","b3","hit","ab")], bin_list=bin_list, nbins=c(7,7,6,6), strict=TRUE)
}
Sys.time()-timer


timer <- Sys.time()
for(i in 1:runs){
bin_index_finder(bb_players[1,c("b2","b3","hit","ab")],iq_def$bin_bounds, iq_def$nbins, strict=TRUE)
}
Sys.time()-timer





# OLD JUNK (may need for timing comparison of R-tree search to linear search later)
#--------------------------------------
### OLD Helper function for checking if a vector is in a p-dimensional bin, defined by 2*p boundaries
# x = p-dimensional vector
# bin_bounds = 2*p dimensional boundary matrix (like in iq-binning definition list)
#!# need to adapt to allow bin allocations for observations outside of observed bins
# bin_index_finder <- function(x, bin_bounds, nbins, strict=TRUE){ 
#   p = length(x)
#   b = nrow(bin_bounds)
#   if(strict==TRUE) {
#     xrep_mat = matrix(rep(x,b),ncol=p,byrow=TRUE)
#     idx <- which(rowSums(bin_bounds[,seq(1,2*p-1,by=2)] < xrep_mat & xrep_mat <= bin_bounds[,seq(2,2*p,by=2)])==p)
#     if(length(idx)==0L) idx <- NA
#   }else{
#     #!# put process for allocating outside bins
#     check_matrix <- matrix(rep(NA,b*p*2),ncol=p*2,byrow=TRUE)
#     for (d in 1:p){
#       blocks <- prod(nbins[1:d-1])
#       blocks_n <- b/blocks
#       subblocks <- prod(nbins[1:d])
#       subblocks_n <- b/subblocks
#       # rows with lowest bin in each strata from last dimension
#       cond_lower <- rep(seq(0,b-blocks_n,by=blocks_n),each=subblocks_n) + rep(seq(1,subblocks_n,by=1),blocks)
#       # rows with highest bin in each strata from last dimension
#       cond_upper <- rep(seq(0,b-blocks_n,by=blocks_n),each=subblocks_n) + rep(seq(blocks_n-subblocks_n+1, blocks_n,by=1),blocks)
#       
#       above_lb <- bin_bounds[,d*2-1] < as.numeric(x[d]) 
#       above_lb[cond_lower] <- TRUE
#       check_matrix[,d*2-1] <- above_lb
#       
#       below_ub <- as.numeric(x[d]) <= bin_bounds[,d*2]
#       below_ub[cond_upper] <- TRUE
#       check_matrix[,d*2] <- below_ub
#     }
#     idx <- which(rowSums(check_matrix)==p*2)
#     
#   }
#   return(idx)
# } 
# myiq <- iqnn(iris, y="Petal.Length", bin_cols=c("Sepal.Length","Sepal.Width","Petal.Width"), nbins=c(3,5,2), jit=rep(.001,3))
# new_row <- iris[1,c("Sepal.Length","Sepal.Width","Petal.Width")]
# new_row_index <- bin_index_finder(new_row, myiq$bin_bounds, myiq$nbins)
# new_row
# myiq$bin_bounds[new_row_index,]
# myiq$bin_centers[new_row_index,]
# myiq$bin_stats[new_row_index,]
# 
# bin_index_finder(c(5,7,7), myiq$bin_bounds, myiq$nbins, strict=TRUE)
# bin_index_finder(c(5,7,7), myiq$bin_bounds, myiq$nbins, strict=FALSE)


# #--------------------------------------
# ### function to suggesting best number of bins under contraints
# # Constraint 1: nbins_1=nbins_2=...=nbins_p
# # Constraint 2: each bin with <= k neighbors (conservative approx to knn)
# roots_for_nbins <- function(x, p, k){
#   nbin_opt <- x/k
#   rep(ceiling(nbin_opt^(1/p)),p)
# }
# # Test with goal to mimic 10-nn with p=3 dimensions
# roots_for_nbins(270,3,10)
# 270/prod(roots_for_nbins(270,3,10))
# roots_for_nbins(122,3,10)
# 122/prod(roots_for_nbins(122,3,10)) # very rough approx between 81 and 270 due to x^3*10
# 
# ### function to suggesting best number of bins under more appropriate contraints
# # Constraint 1: nbins_1>=nbins_2>=...>=nbins_p
# # Constraint 2: each bin with <= k neighbors (conservative approx to knn)
# approxknn_nbins <- function(x, p, k){
#   #!# work out code for repeatedly adding 1 to some nbins until tips over k per bin
# }
